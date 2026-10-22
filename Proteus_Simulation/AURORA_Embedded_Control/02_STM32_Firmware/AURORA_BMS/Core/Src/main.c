#include "main.h"
#include <stdio.h>
#include <string.h>

/* -------------------------------------------------------------------------- */
/* PERIPHERALS                                                                */
/* -------------------------------------------------------------------------- */

ADC_HandleTypeDef hadc1;

UART_HandleTypeDef huart1;   /* DEBUG SCREEN - PA9 - 115200 */
UART_HandleTypeDef huart2;   /* BMS -> VCU - PA2 - 9600 */

/* -------------------------------------------------------------------------- */
/* BMS STATE                                                                  */
/* -------------------------------------------------------------------------- */

typedef enum
{
    BMS_NORMAL = 0,
    BMS_WARNING,
    BMS_DERATE,
    BMS_SHUTDOWN
} BMS_State_t;

BMS_State_t bms_state = BMS_NORMAL;

uint32_t adc_value = 0;

uint16_t temperature_x10 = 0;

uint8_t torque_limit_percent = 100;

char tx_buffer[180];

/* -------------------------------------------------------------------------- */
/* PROTOTYPES                                                                 */
/* -------------------------------------------------------------------------- */

void SystemClock_Config(void);

static void MX_GPIO_Init(void);
static void MX_ADC1_Init(void);
static void MX_USART1_UART_Init(void);
static void MX_USART2_UART_Init(void);

static void Read_Temperature(void);
static void Update_BMS_State(void);
static void Update_LEDs(void);
static void Send_BMS_State(void);
static void Print_BMS_Status(void);

/* -------------------------------------------------------------------------- */
/* HELPERS                                                                    */
/* -------------------------------------------------------------------------- */

static const char *BMS_State_Text(BMS_State_t state)
{
    switch (state)
    {
        case BMS_NORMAL:
            return "NORMAL";

        case BMS_WARNING:
            return "WARNING";

        case BMS_DERATE:
            return "DERATE";

        case BMS_SHUTDOWN:
            return "SHUTDOWN";

        default:
            return "UNKNOWN";
    }
}

static uint8_t BMS_State_Byte(BMS_State_t state)
{
    switch (state)
    {
        case BMS_NORMAL:
            return 'N';

        case BMS_WARNING:
            return 'W';

        case BMS_DERATE:
            return 'D';

        case BMS_SHUTDOWN:
            return 'S';

        default:
            return 'S';
    }
}

/* -------------------------------------------------------------------------- */
/* TEMPERATURE                                                                */
/* -------------------------------------------------------------------------- */

static void Read_Temperature(void)
{
    HAL_ADC_Start(&hadc1);

    if (HAL_ADC_PollForConversion(&hadc1, 5) == HAL_OK)
    {
        adc_value = HAL_ADC_GetValue(&hadc1);
    }

    HAL_ADC_Stop(&hadc1);

    /*
     * DEMO SCALE:
     *
     * 0.0 V ->   0.0 C
     * 3.3 V -> 100.0 C
     */

    temperature_x10 =
        (uint16_t)(
            ((uint32_t)adc_value * 1000U + 2047U)
            / 4095U
        );
}

/* -------------------------------------------------------------------------- */
/* BMS STATE                                                                  */
/* -------------------------------------------------------------------------- */

static void Update_BMS_State(void)
{
    if (temperature_x10 < 300U)
    {
        bms_state = BMS_NORMAL;
        torque_limit_percent = 100;
    }

    else if (temperature_x10 < 400U)
    {
        bms_state = BMS_WARNING;
        torque_limit_percent = 80;
    }

    else if (temperature_x10 < 800U)
    {
        bms_state = BMS_DERATE;
        torque_limit_percent = 50;
    }

    else
    {
        bms_state = BMS_SHUTDOWN;
        torque_limit_percent = 0;
    }
}

/* -------------------------------------------------------------------------- */
/* LEDs                                                                       */
/* -------------------------------------------------------------------------- */

static void Update_LEDs(void)
{
    static uint32_t last_blink_time = 0;
    static uint8_t blink_state = 0;

    switch (bms_state)
    {
        case BMS_NORMAL:

            HAL_GPIO_WritePin(
                GPIOB,
                GPIO_PIN_0,
                GPIO_PIN_SET
            );

            HAL_GPIO_WritePin(
                GPIOB,
                GPIO_PIN_1,
                GPIO_PIN_RESET
            );

            break;


        case BMS_WARNING:

            HAL_GPIO_WritePin(
                GPIOB,
                GPIO_PIN_0,
                GPIO_PIN_SET
            );

            HAL_GPIO_WritePin(
                GPIOB,
                GPIO_PIN_1,
                GPIO_PIN_SET
            );

            break;


        case BMS_DERATE:

            HAL_GPIO_WritePin(
                GPIOB,
                GPIO_PIN_0,
                GPIO_PIN_RESET
            );

            HAL_GPIO_WritePin(
                GPIOB,
                GPIO_PIN_1,
                GPIO_PIN_SET
            );

            break;


        case BMS_SHUTDOWN:

            if (
                (HAL_GetTick() - last_blink_time)
                >= 250U
               )
            {
                blink_state ^= 1U;

                last_blink_time =
                    HAL_GetTick();
            }

            HAL_GPIO_WritePin(
                GPIOB,
                GPIO_PIN_0,
                blink_state
                    ? GPIO_PIN_SET
                    : GPIO_PIN_RESET
            );

            HAL_GPIO_WritePin(
                GPIOB,
                GPIO_PIN_1,
                blink_state
                    ? GPIO_PIN_SET
                    : GPIO_PIN_RESET
            );

            break;
    }
}

/* -------------------------------------------------------------------------- */
/* BMS -> VCU                                                                 */
/* -------------------------------------------------------------------------- */

static void Send_BMS_State(void)
{
    uint8_t message =
        BMS_State_Byte(bms_state);

    HAL_UART_Transmit(
        &huart2,
        &message,
        1,
        10
    );
}

/* -------------------------------------------------------------------------- */
/* BMS DEBUG SCREEN                                                           */
/* -------------------------------------------------------------------------- */

static void Print_BMS_Status(void)
{
    snprintf(
        tx_buffer,
        sizeof(tx_buffer),

        "\r\n"
        "AURORA BMS\r\n"
        "TEMP: %u.%u C\r\n"
        "STATE: %s\r\n"
        "TORQUE LIMIT: %u %%\r\n"
        "VCU LINK: TX\r\n"
        "-------------------------\r\n",

        temperature_x10 / 10U,
        temperature_x10 % 10U,

        BMS_State_Text(bms_state),

        torque_limit_percent
    );

    HAL_UART_Transmit(
        &huart1,
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


    const char startup[] =
        "\r\nAURORA BMS READY\r\n";


    HAL_UART_Transmit(
        &huart1,
        (uint8_t *)startup,
        sizeof(startup) - 1U,
        50
    );


    uint32_t last_sensor_time = 0;

    uint32_t last_vcu_tx_time = 0;

    uint32_t last_debug_time = 0;

    BMS_State_t last_printed_state =
        (BMS_State_t)255;


    while (1)
    {
        uint32_t now =
            HAL_GetTick();


        /* Temperature */

        if (
            (now - last_sensor_time)
            >= 100U
           )
        {
            Read_Temperature();

            Update_BMS_State();

            Update_LEDs();

            last_sensor_time =
                now;
        }


        /* Machine heartbeat */

        if (
            (now - last_vcu_tx_time)
            >= 500U
           )
        {
            Send_BMS_State();

            last_vcu_tx_time =
                now;
        }


        /*
         * Human display:
         *
         * Immediately when BMS state changes,
         * otherwise only once every 2 seconds.
         */

        if (
            (bms_state != last_printed_state) ||
            ((now - last_debug_time) >= 2000U)
           )
        {
            Print_BMS_Status();

            last_printed_state =
                bms_state;

            last_debug_time =
                now;
        }


        HAL_Delay(5);
    }
}

/* -------------------------------------------------------------------------- */
/* CLOCK                                                                      */
/* -------------------------------------------------------------------------- */

void SystemClock_Config(void)
{
    RCC_OscInitTypeDef RCC_OscInitStruct =
        {0};

    RCC_ClkInitTypeDef RCC_ClkInitStruct =
        {0};


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


    if (
        HAL_RCC_OscConfig(
            &RCC_OscInitStruct
        ) != HAL_OK
       )
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


    if (
        HAL_RCC_ClockConfig(
            &RCC_ClkInitStruct,
            FLASH_LATENCY_0
        ) != HAL_OK
       )
    {
        Error_Handler();
    }
}

/* -------------------------------------------------------------------------- */
/* GPIO                                                                       */
/* -------------------------------------------------------------------------- */

static void MX_GPIO_Init(void)
{
    GPIO_InitTypeDef GPIO_InitStruct =
        {0};


    __HAL_RCC_GPIOA_CLK_ENABLE();

    __HAL_RCC_GPIOB_CLK_ENABLE();


    /* LEDs */

    HAL_GPIO_WritePin(
        GPIOB,
        GPIO_PIN_0 |
        GPIO_PIN_1,
        GPIO_PIN_RESET
    );


    GPIO_InitStruct.Pin =
        GPIO_PIN_0 |
        GPIO_PIN_1;

    GPIO_InitStruct.Mode =
        GPIO_MODE_OUTPUT_PP;

    GPIO_InitStruct.Pull =
        GPIO_NOPULL;

    GPIO_InitStruct.Speed =
        GPIO_SPEED_FREQ_LOW;


    HAL_GPIO_Init(
        GPIOB,
        &GPIO_InitStruct
    );


    /* ADC PA0 */

    GPIO_InitStruct.Pin =
        GPIO_PIN_0;

    GPIO_InitStruct.Mode =
        GPIO_MODE_ANALOG;

    GPIO_InitStruct.Pull =
        GPIO_NOPULL;


    HAL_GPIO_Init(
        GPIOA,
        &GPIO_InitStruct
    );


    /* USART1 TX PA9 */

    GPIO_InitStruct.Pin =
        GPIO_PIN_9;

    GPIO_InitStruct.Mode =
        GPIO_MODE_AF_PP;

    GPIO_InitStruct.Pull =
        GPIO_NOPULL;

    GPIO_InitStruct.Speed =
        GPIO_SPEED_FREQ_LOW;

    GPIO_InitStruct.Alternate =
        GPIO_AF7_USART1;


    HAL_GPIO_Init(
        GPIOA,
        &GPIO_InitStruct
    );


    /* USART2 TX PA2 */

    GPIO_InitStruct.Pin =
        GPIO_PIN_2;

    GPIO_InitStruct.Alternate =
        GPIO_AF7_USART2;


    HAL_GPIO_Init(
        GPIOA,
        &GPIO_InitStruct
    );
}

/* -------------------------------------------------------------------------- */
/* ADC                                                                        */
/* -------------------------------------------------------------------------- */

static void MX_ADC1_Init(void)
{
    ADC_ChannelConfTypeDef sConfig =
        {0};


    __HAL_RCC_ADC1_CLK_ENABLE();


    hadc1.Instance =
        ADC1;


    hadc1.Init.ClockPrescaler =
        ADC_CLOCK_SYNC_PCLK_DIV2;


    hadc1.Init.Resolution =
        ADC_RESOLUTION_12B;


    hadc1.Init.ScanConvMode =
        DISABLE;


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
        1;


    hadc1.Init.DMAContinuousRequests =
        DISABLE;


    hadc1.Init.EOCSelection =
        ADC_EOC_SINGLE_CONV;


    if (
        HAL_ADC_Init(
            &hadc1
        ) != HAL_OK
       )
    {
        Error_Handler();
    }


    sConfig.Channel =
        ADC_CHANNEL_0;


    sConfig.Rank =
        1;


    sConfig.SamplingTime =
        ADC_SAMPLETIME_84CYCLES;


    if (
        HAL_ADC_ConfigChannel(
            &hadc1,
            &sConfig
        ) != HAL_OK
       )
    {
        Error_Handler();
    }
}

/* -------------------------------------------------------------------------- */
/* USART1 DEBUG                                                               */
/* -------------------------------------------------------------------------- */

static void MX_USART1_UART_Init(void)
{
    __HAL_RCC_USART1_CLK_ENABLE();


    huart1.Instance =
        USART1;


    huart1.Init.BaudRate =
        115200;


    huart1.Init.WordLength =
        UART_WORDLENGTH_8B;


    huart1.Init.StopBits =
        UART_STOPBITS_1;


    huart1.Init.Parity =
        UART_PARITY_NONE;


    huart1.Init.Mode =
        UART_MODE_TX;


    huart1.Init.HwFlowCtl =
        UART_HWCONTROL_NONE;


    huart1.Init.OverSampling =
        UART_OVERSAMPLING_16;


    if (
        HAL_UART_Init(
            &huart1
        ) != HAL_OK
       )
    {
        Error_Handler();
    }
}

/* -------------------------------------------------------------------------- */
/* USART2 MACHINE LINK                                                        */
/* -------------------------------------------------------------------------- */

static void MX_USART2_UART_Init(void)
{
    __HAL_RCC_USART2_CLK_ENABLE();


    huart2.Instance =
        USART2;


    huart2.Init.BaudRate =
        9600;


    huart2.Init.WordLength =
        UART_WORDLENGTH_8B;


    huart2.Init.StopBits =
        UART_STOPBITS_1;


    huart2.Init.Parity =
        UART_PARITY_NONE;


    huart2.Init.Mode =
        UART_MODE_TX;


    huart2.Init.HwFlowCtl =
        UART_HWCONTROL_NONE;


    huart2.Init.OverSampling =
        UART_OVERSAMPLING_16;


    if (
        HAL_UART_Init(
            &huart2
        ) != HAL_OK
       )
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
