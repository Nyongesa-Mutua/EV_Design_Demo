#include "main.h"
#include <stdio.h>
#include <string.h>

/* -------------------------------------------------------------------------- */
/* PERIPHERALS                                                                */
/* -------------------------------------------------------------------------- */

ADC_HandleTypeDef hadc1;

UART_HandleTypeDef huart1;   /* VCU <-> MOTOR: PA9 TX / PA10 RX @ 9600 */
UART_HandleTypeDef huart2;   /* BMS -> VCU: PA3 RX @ 9600 */
UART_HandleTypeDef huart6;   /* VCU SCREEN: PC6 TX @ 115200 */

/* -------------------------------------------------------------------------- */
/* TYPES                                                                      */
/* -------------------------------------------------------------------------- */

typedef enum
{
    BMS_NORMAL = 0,
    BMS_WARNING,
    BMS_DERATE,
    BMS_SHUTDOWN,
    BMS_UNKNOWN
} BMS_State_t;

typedef enum
{
    VCU_OFF = 0,
    VCU_READY,
    VCU_DRIVE,
    VCU_REGEN,
    VCU_CHARGE,
    VCU_FAULT
} VCU_State_t;

typedef enum
{
    SOC_OK = 0,
    SOC_LOW,
    SOC_DERATE,
    SOC_CRITICAL
} SOC_State_t;

/* -------------------------------------------------------------------------- */
/* DTC                                                                        */
/* -------------------------------------------------------------------------- */

#define DTC_NONE            0U
#define DTC_MOTOR_HARDWARE  1U

/* -------------------------------------------------------------------------- */
/* GLOBAL STATE                                                               */
/* -------------------------------------------------------------------------- */

BMS_State_t bms_state = BMS_UNKNOWN;
VCU_State_t vehicle_state = VCU_OFF;
SOC_State_t soc_state = SOC_OK;

uint32_t last_bms_message_time = 0;
uint32_t last_motor_feedback_time = 0;

uint8_t bms_torque_limit_percent = 0;
uint8_t soc_torque_limit_percent = 100;
uint8_t effective_torque_limit_percent = 0;

uint8_t motor_feedback_fault = 0;
uint8_t motor_dtc_code = DTC_NONE;

uint32_t accelerator_adc = 0;
uint32_t brake_adc = 0;
uint32_t soc_adc = 0;

uint8_t accelerator_percent = 0;
uint8_t brake_percent = 0;
uint8_t soc_sensor_percent = 50;

uint8_t soc_percent = 50;
uint8_t soc_initialized = 0;

uint8_t ignition_on = 0;
uint8_t charger_connected = 0;

uint8_t final_motor_command = 0;
uint8_t regen_percent = 0;

uint8_t motor_packet[2];

char tx_buffer[250];

/* -------------------------------------------------------------------------- */
/* PROTOTYPES                                                                 */
/* -------------------------------------------------------------------------- */

void SystemClock_Config(void);

static void MX_GPIO_Init(void);
static void MX_ADC1_Init(void);
static void MX_USART1_UART_Init(void);
static void MX_USART2_UART_Init(void);
static void MX_USART6_UART_Init(void);

static void Poll_BMS(void);
static void Poll_Motor(void);

static void Read_Inputs(void);

static void Update_SOC_State(void);
static void Update_Vehicle_State(void);
static void Update_Motor_Command(void);
static void Update_SOC_Simulation(void);

static void Send_Motor_Command(void);
static void Print_Status(void);

/* -------------------------------------------------------------------------- */
/* TEXT HELPERS                                                               */
/* -------------------------------------------------------------------------- */

static const char *Vehicle_State_Text(VCU_State_t state)
{
    switch (state)
    {
        case VCU_OFF:    return "OFF";
        case VCU_READY:  return "READY";
        case VCU_DRIVE:  return "DRIVE";
        case VCU_REGEN:  return "REGEN";
        case VCU_CHARGE: return "CHARGE";
        case VCU_FAULT:  return "FAULT";
        default:         return "UNKNOWN";
    }
}

static const char *BMS_State_Text(BMS_State_t state)
{
    switch (state)
    {
        case BMS_NORMAL:   return "NORMAL";
        case BMS_WARNING:  return "WARNING";
        case BMS_DERATE:   return "DERATE";
        case BMS_SHUTDOWN: return "SHUTDOWN";
        default:           return "UNKNOWN";
    }
}

/* -------------------------------------------------------------------------- */
/* BMS RX                                                                     */
/* -------------------------------------------------------------------------- */

static void Poll_BMS(void)
{
    uint8_t rx;

    for (uint8_t i = 0; i < 4U; i++)
    {
        if (HAL_UART_Receive(&huart2, &rx, 1, 1) != HAL_OK)
        {
            break;
        }

        switch (rx)
        {
            case 'N':
                bms_state = BMS_NORMAL;
                bms_torque_limit_percent = 100;
                break;

            case 'W':
                bms_state = BMS_WARNING;
                bms_torque_limit_percent = 80;
                break;

            case 'D':
                bms_state = BMS_DERATE;
                bms_torque_limit_percent = 50;
                break;

            case 'S':
                bms_state = BMS_SHUTDOWN;
                bms_torque_limit_percent = 0;
                break;

            default:
                continue;
        }

        last_bms_message_time = HAL_GetTick();
    }
}

/* -------------------------------------------------------------------------- */
/* MOTOR FEEDBACK                                                             */
/* -------------------------------------------------------------------------- */

static void Poll_Motor(void)
{
    uint8_t rx;

    for (uint8_t i = 0; i < 4U; i++)
    {
        if (HAL_UART_Receive(&huart1, &rx, 1, 1) != HAL_OK)
        {
            break;
        }

        if (rx == 'O')
        {
            motor_feedback_fault = 0;
            motor_dtc_code = DTC_NONE;
            last_motor_feedback_time = HAL_GetTick();
        }

        else if (rx == 'F')
        {
            motor_feedback_fault = 1;
            motor_dtc_code = DTC_MOTOR_HARDWARE;
            last_motor_feedback_time = HAL_GetTick();
        }
    }
}

/* -------------------------------------------------------------------------- */
/* INPUTS                                                                     */
/* -------------------------------------------------------------------------- */

static void Read_Inputs(void)
{
    HAL_ADC_Start(&hadc1);

    if (HAL_ADC_PollForConversion(&hadc1, 5) == HAL_OK)
    {
        accelerator_adc = HAL_ADC_GetValue(&hadc1);
    }

    if (HAL_ADC_PollForConversion(&hadc1, 5) == HAL_OK)
    {
        brake_adc = HAL_ADC_GetValue(&hadc1);
    }

    if (HAL_ADC_PollForConversion(&hadc1, 5) == HAL_OK)
    {
        soc_adc = HAL_ADC_GetValue(&hadc1);
    }

    HAL_ADC_Stop(&hadc1);

    accelerator_percent =
        (uint8_t)(((uint32_t)accelerator_adc * 100U + 2047U) / 4095U);

    brake_percent =
        (uint8_t)(((uint32_t)brake_adc * 100U + 2047U) / 4095U);

    soc_sensor_percent =
        (uint8_t)(((uint32_t)soc_adc * 100U + 2047U) / 4095U);

    if (accelerator_percent > 100U)
        accelerator_percent = 100U;

    if (brake_percent > 100U)
        brake_percent = 100U;

    if (soc_sensor_percent > 100U)
        soc_sensor_percent = 100U;

    ignition_on =
        (HAL_GPIO_ReadPin(GPIOA, GPIO_PIN_4) == GPIO_PIN_SET);

    charger_connected =
        (HAL_GPIO_ReadPin(GPIOA, GPIO_PIN_5) == GPIO_PIN_SET);

    if (!soc_initialized)
    {
        soc_percent = soc_sensor_percent;
        soc_initialized = 1;
    }

    if ((!ignition_on) && (!charger_connected))
    {
        soc_percent = soc_sensor_percent;
    }
}

/* -------------------------------------------------------------------------- */
/* SOC                                                                        */
/* -------------------------------------------------------------------------- */

static void Update_SOC_State(void)
{
    if (soc_percent < 5U)
    {
        soc_state = SOC_CRITICAL;
        soc_torque_limit_percent = 0;
    }

    else if (soc_percent < 10U)
    {
        soc_state = SOC_DERATE;
        soc_torque_limit_percent = 50;
    }

    else if (soc_percent <= 20U)
    {
        soc_state = SOC_LOW;
        soc_torque_limit_percent = 100;
    }

    else
    {
        soc_state = SOC_OK;
        soc_torque_limit_percent = 100;
    }

    effective_torque_limit_percent =
        (bms_torque_limit_percent < soc_torque_limit_percent)
        ? bms_torque_limit_percent
        : soc_torque_limit_percent;
}

/* -------------------------------------------------------------------------- */
/* VEHICLE STATE                                                              */
/* -------------------------------------------------------------------------- */

static void Update_Vehicle_State(void)
{
    uint32_t now = HAL_GetTick();

    uint8_t bms_timeout =
        ((now > 2000U) &&
         ((now - last_bms_message_time) > 1500U));

    if ((bms_state == BMS_SHUTDOWN) ||
        bms_timeout ||
        motor_feedback_fault ||
        (soc_state == SOC_CRITICAL))
    {
        vehicle_state = VCU_FAULT;
        return;
    }

    if (charger_connected)
    {
        vehicle_state = VCU_CHARGE;
        return;
    }

    if (!ignition_on)
    {
        vehicle_state = VCU_OFF;
        return;
    }

    if (brake_percent >= 5U)
    {
        vehicle_state = VCU_REGEN;
        return;
    }

    if (accelerator_percent > 2U)
    {
        vehicle_state = VCU_DRIVE;
        return;
    }

    vehicle_state = VCU_READY;
}

/* -------------------------------------------------------------------------- */
/* MOTOR COMMAND                                                              */
/* -------------------------------------------------------------------------- */

static void Update_Motor_Command(void)
{
    final_motor_command = 0;
    regen_percent = 0;

    if (vehicle_state == VCU_DRIVE)
    {
        final_motor_command =
            (uint8_t)(
                ((uint32_t)accelerator_percent *
                 effective_torque_limit_percent)
                / 100U
            );
    }

    else if (vehicle_state == VCU_REGEN)
    {
        regen_percent =
            (uint8_t)(
                ((uint32_t)(brake_percent - 5U) * 60U)
                / 95U
            );

        if (regen_percent > 60U)
        {
            regen_percent = 60U;
        }
    }
}

/* -------------------------------------------------------------------------- */
/* SOC DEMO                                                                   */
/* -------------------------------------------------------------------------- */

static void Update_SOC_Simulation(void)
{
    static uint32_t last_charge_time = 0;
    static uint32_t last_drive_time = 0;
    static uint32_t last_regen_time = 0;

    uint32_t now = HAL_GetTick();

    if (vehicle_state == VCU_CHARGE)
    {
        if ((now - last_charge_time) >= 1000U)
        {
            if (soc_percent < 100U)
                soc_percent++;

            last_charge_time = now;
        }

        return;
    }

    if ((vehicle_state == VCU_DRIVE) &&
        (final_motor_command > 0U))
    {
        if ((now - last_drive_time) >= 3000U)
        {
            if (soc_percent > 0U)
                soc_percent--;

            last_drive_time = now;
        }
    }
    else
    {
        last_drive_time = now;
    }

    if ((vehicle_state == VCU_REGEN) &&
        (regen_percent > 10U))
    {
        if ((now - last_regen_time) >= 5000U)
        {
            if (soc_percent < 100U)
                soc_percent++;

            last_regen_time = now;
        }
    }
    else
    {
        last_regen_time = now;
    }
}

/* -------------------------------------------------------------------------- */
/* VCU -> MOTOR                                                               */
/* -------------------------------------------------------------------------- */

static void Send_Motor_Command(void)
{
    uint8_t mode = 'S';
    uint8_t value = 0;

    if (vehicle_state == VCU_DRIVE)
    {
        mode = 'D';
        value = final_motor_command;
    }

    else if (vehicle_state == VCU_REGEN)
    {
        mode = 'R';
        value = regen_percent;
    }

    motor_packet[0] = mode;
    motor_packet[1] = value;

    HAL_UART_Transmit(
        &huart1,
        motor_packet,
        2,
        10
    );
}

/* -------------------------------------------------------------------------- */
/* VCU SCREEN                                                                 */
/* -------------------------------------------------------------------------- */

static void Print_Status(void)
{
    snprintf(
        tx_buffer,
        sizeof(tx_buffer),

        "\r\n"
        "AURORA VCU\r\n"
        "MODE: %s | BMS: %s\r\n"
        "SOC: %u %%\r\n"
        "ACC: %u %% | BRK: %u %%\r\n"
        "LIMIT: %u %%\r\n"
        "MTR CMD: %u %% | REGEN: %u %%\r\n"
        "MOTOR: %s | DTC: %u\r\n"
        "--------------------------------\r\n",

        Vehicle_State_Text(vehicle_state),
        BMS_State_Text(bms_state),

        soc_percent,

        accelerator_percent,
        brake_percent,

        effective_torque_limit_percent,

        final_motor_command,
        regen_percent,

        motor_feedback_fault ? "FAULT" : "OK",

        motor_dtc_code
    );

    HAL_UART_Transmit(
        &huart6,
        (uint8_t *)tx_buffer,
        strlen(tx_buffer),
        50
    );
}

/* -------------------------------------------------------------------------- */
/* MAIN                                                                       */
/* -------------------------------------------------------------------------- */

int main(void)
{
    HAL_Init();

    SystemClock_Config();

    MX_GPIO_Init();
    MX_ADC1_Init();

    MX_USART1_UART_Init();
    MX_USART2_UART_Init();
    MX_USART6_UART_Init();

    const char startup[] =
        "\r\nAURORA VCU READY\r\n";

    HAL_UART_Transmit(
        &huart6,
        (uint8_t *)startup,
        sizeof(startup) - 1U,
        50
    );

    uint32_t last_control_time = 0;
    uint32_t last_motor_tx_time = 0;
    uint32_t last_debug_time = 0;

    while (1)
    {
        uint32_t now = HAL_GetTick();

        Poll_BMS();

        Poll_Motor();

        if ((now - last_control_time) >= 50U)
        {
            Read_Inputs();

            Update_SOC_State();

            Update_Vehicle_State();

            Update_Motor_Command();

            Update_SOC_Simulation();

            Update_SOC_State();

            last_control_time = now;
        }

        if ((now - last_motor_tx_time) >= 200U)
        {
            Send_Motor_Command();

            last_motor_tx_time = now;
        }

        if ((now - last_debug_time) >= 1000U)
        {
            Print_Status();

            last_debug_time = now;
        }

        HAL_Delay(2);
    }
}

/* -------------------------------------------------------------------------- */
/* CLOCK                                                                      */
/* -------------------------------------------------------------------------- */

void SystemClock_Config(void)
{
    RCC_OscInitTypeDef RCC_OscInitStruct = {0};
    RCC_ClkInitTypeDef RCC_ClkInitStruct = {0};

    __HAL_RCC_PWR_CLK_ENABLE();

    __HAL_PWR_VOLTAGESCALING_CONFIG(
        PWR_REGULATOR_VOLTAGE_SCALE2
    );

    RCC_OscInitStruct.OscillatorType =
        RCC_OSCILLATORTYPE_HSI;

    RCC_OscInitStruct.HSIState =
        RCC_HSI_ON;

    RCC_OscInitStruct.HSICalibrationValue =
        RCC_HSICALIBRATION_DEFAULT;

    RCC_OscInitStruct.PLL.PLLState =
        RCC_PLL_NONE;

    if (HAL_RCC_OscConfig(&RCC_OscInitStruct) != HAL_OK)
    {
        Error_Handler();
    }

    RCC_ClkInitStruct.ClockType =
        RCC_CLOCKTYPE_HCLK |
        RCC_CLOCKTYPE_SYSCLK |
        RCC_CLOCKTYPE_PCLK1 |
        RCC_CLOCKTYPE_PCLK2;

    RCC_ClkInitStruct.SYSCLKSource =
        RCC_SYSCLKSOURCE_HSI;

    RCC_ClkInitStruct.AHBCLKDivider =
        RCC_SYSCLK_DIV1;

    RCC_ClkInitStruct.APB1CLKDivider =
        RCC_HCLK_DIV1;

    RCC_ClkInitStruct.APB2CLKDivider =
        RCC_HCLK_DIV1;

    if (HAL_RCC_ClockConfig(
            &RCC_ClkInitStruct,
            FLASH_LATENCY_0
        ) != HAL_OK)
    {
        Error_Handler();
    }
}

/* -------------------------------------------------------------------------- */
/* GPIO                                                                       */
/* -------------------------------------------------------------------------- */

static void MX_GPIO_Init(void)
{
    GPIO_InitTypeDef GPIO_InitStruct = {0};

    __HAL_RCC_GPIOA_CLK_ENABLE();
    __HAL_RCC_GPIOC_CLK_ENABLE();

    /* ADC PA0, PA1, PA7 */

    GPIO_InitStruct.Pin =
        GPIO_PIN_0 |
        GPIO_PIN_1 |
        GPIO_PIN_7;

    GPIO_InitStruct.Mode =
        GPIO_MODE_ANALOG;

    GPIO_InitStruct.Pull =
        GPIO_NOPULL;

    HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

    /* IGN PA4 + CHG PA5 */

    GPIO_InitStruct.Pin =
        GPIO_PIN_4 |
        GPIO_PIN_5;

    GPIO_InitStruct.Mode =
        GPIO_MODE_INPUT;

    GPIO_InitStruct.Pull =
        GPIO_PULLDOWN;

    HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

    /* USART1 Motor PA9 / PA10 */

    GPIO_InitStruct.Pin =
        GPIO_PIN_9 |
        GPIO_PIN_10;

    GPIO_InitStruct.Mode =
        GPIO_MODE_AF_PP;

    GPIO_InitStruct.Pull =
        GPIO_NOPULL;

    GPIO_InitStruct.Speed =
        GPIO_SPEED_FREQ_LOW;

    GPIO_InitStruct.Alternate =
        GPIO_AF7_USART1;

    HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

    /* USART2 BMS PA2 / PA3 */

    GPIO_InitStruct.Pin =
        GPIO_PIN_2 |
        GPIO_PIN_3;

    GPIO_InitStruct.Alternate =
        GPIO_AF7_USART2;

    HAL_GPIO_Init(GPIOA, &GPIO_InitStruct);

    /* USART6 VCU Screen PC6 */

    GPIO_InitStruct.Pin =
        GPIO_PIN_6;

    GPIO_InitStruct.Alternate =
        GPIO_AF8_USART6;

    HAL_GPIO_Init(GPIOC, &GPIO_InitStruct);
}

/* -------------------------------------------------------------------------- */
/* ADC                                                                        */
/* -------------------------------------------------------------------------- */

static void MX_ADC1_Init(void)
{
    ADC_ChannelConfTypeDef sConfig = {0};

    __HAL_RCC_ADC1_CLK_ENABLE();

    hadc1.Instance = ADC1;

    hadc1.Init.ClockPrescaler =
        ADC_CLOCK_SYNC_PCLK_DIV2;

    hadc1.Init.Resolution =
        ADC_RESOLUTION_12B;

    hadc1.Init.ScanConvMode =
        ENABLE;

    hadc1.Init.ContinuousConvMode =
        DISABLE;

    hadc1.Init.DiscontinuousConvMode =
        DISABLE;

    hadc1.Init.ExternalTrigConvEdge =
        ADC_EXTERNALTRIGCONVEDGE_NONE;

    hadc1.Init.ExternalTrigConv =
        ADC_SOFTWARE_START;

    hadc1.Init.DataAlign =
        ADC_DATAALIGN_RIGHT;

    hadc1.Init.NbrOfConversion =
        3;

    hadc1.Init.DMAContinuousRequests =
        DISABLE;

    hadc1.Init.EOCSelection =
        ADC_EOC_SINGLE_CONV;

    if (HAL_ADC_Init(&hadc1) != HAL_OK)
    {
        Error_Handler();
    }

    sConfig.SamplingTime =
        ADC_SAMPLETIME_84CYCLES;

    sConfig.Channel =
        ADC_CHANNEL_0;

    sConfig.Rank = 1;

    if (HAL_ADC_ConfigChannel(
            &hadc1,
            &sConfig
        ) != HAL_OK)
    {
        Error_Handler();
    }

    sConfig.Channel =
        ADC_CHANNEL_1;

    sConfig.Rank = 2;

    if (HAL_ADC_ConfigChannel(
            &hadc1,
            &sConfig
        ) != HAL_OK)
    {
        Error_Handler();
    }

    sConfig.Channel =
        ADC_CHANNEL_7;

    sConfig.Rank = 3;

    if (HAL_ADC_ConfigChannel(
            &hadc1,
            &sConfig
        ) != HAL_OK)
    {
        Error_Handler();
    }
}

/* -------------------------------------------------------------------------- */
/* USART1 MOTOR LINK                                                          */
/* -------------------------------------------------------------------------- */

static void MX_USART1_UART_Init(void)
{
    __HAL_RCC_USART1_CLK_ENABLE();

    huart1.Instance = USART1;

    huart1.Init.BaudRate = 9600;

    huart1.Init.WordLength =
        UART_WORDLENGTH_8B;

    huart1.Init.StopBits =
        UART_STOPBITS_1;

    huart1.Init.Parity =
        UART_PARITY_NONE;

    huart1.Init.Mode =
        UART_MODE_TX_RX;

    huart1.Init.HwFlowCtl =
        UART_HWCONTROL_NONE;

    huart1.Init.OverSampling =
        UART_OVERSAMPLING_16;

    if (HAL_UART_Init(&huart1) != HAL_OK)
    {
        Error_Handler();
    }
}

/* -------------------------------------------------------------------------- */
/* USART2 BMS LINK                                                            */
/* -------------------------------------------------------------------------- */

static void MX_USART2_UART_Init(void)
{
    __HAL_RCC_USART2_CLK_ENABLE();

    huart2.Instance = USART2;

    huart2.Init.BaudRate = 9600;

    huart2.Init.WordLength =
        UART_WORDLENGTH_8B;

    huart2.Init.StopBits =
        UART_STOPBITS_1;

    huart2.Init.Parity =
        UART_PARITY_NONE;

    huart2.Init.Mode =
        UART_MODE_TX_RX;

    huart2.Init.HwFlowCtl =
        UART_HWCONTROL_NONE;

    huart2.Init.OverSampling =
        UART_OVERSAMPLING_16;

    if (HAL_UART_Init(&huart2) != HAL_OK)
    {
        Error_Handler();
    }
}

/* -------------------------------------------------------------------------- */
/* USART6 VCU SCREEN                                                          */
/* -------------------------------------------------------------------------- */

static void MX_USART6_UART_Init(void)
{
    __HAL_RCC_USART6_CLK_ENABLE();

    huart6.Instance = USART6;

    huart6.Init.BaudRate = 115200;

    huart6.Init.WordLength =
        UART_WORDLENGTH_8B;

    huart6.Init.StopBits =
        UART_STOPBITS_1;

    huart6.Init.Parity =
        UART_PARITY_NONE;

    huart6.Init.Mode =
        UART_MODE_TX;

    huart6.Init.HwFlowCtl =
        UART_HWCONTROL_NONE;

    huart6.Init.OverSampling =
        UART_OVERSAMPLING_16;

    if (HAL_UART_Init(&huart6) != HAL_OK)
    {
        Error_Handler();
    }
}

/* -------------------------------------------------------------------------- */
/* ERROR                                                                      */
/* -------------------------------------------------------------------------- */

void Error_Handler(void)
{
    __disable_irq();

    while (1)
    {
    }
}

#ifdef USE_FULL_ASSERT

void assert_failed(
    uint8_t *file,
    uint32_t line
)
{
}

#endif
