#include "main.h"
#include <stdio.h>
#include <string.h>

/* -------------------------------------------------------------------------- */
/* PERIPHERALS                                                                */
/* -------------------------------------------------------------------------- */

UART_HandleTypeDef huart1;   /* MOTOR SCREEN PA9 @115200 */
UART_HandleTypeDef huart2;   /* VCU LINK PA2/PA3 @9600 */

TIM_HandleTypeDef htim3;     /* PA6 TIM3_CH1 */

/* -------------------------------------------------------------------------- */
/* TYPES                                                                      */
/* -------------------------------------------------------------------------- */

typedef enum
{
    MOTOR_STOP = 0,
    MOTOR_DRIVE,
    MOTOR_REGEN,
    MOTOR_FAULT
} Motor_Mode_t;

/* -------------------------------------------------------------------------- */
/* STATE                                                                      */
/* -------------------------------------------------------------------------- */

Motor_Mode_t motor_mode = MOTOR_STOP;

uint8_t received_mode = 'S';
uint8_t received_value = 0;

uint8_t torque_request = 0;
uint8_t regen_request = 0;
uint8_t pwm_percent = 0;

uint8_t hardware_fault = 0;

char tx_buffer[220];

/* -------------------------------------------------------------------------- */
/* PROTOTYPES                                                                 */
/* -------------------------------------------------------------------------- */

void SystemClock_Config(void);

static void MX_GPIO_Init(void);
static void MX_USART1_UART_Init(void);
static void MX_USART2_UART_Init(void);
static void MX_TIM3_Init(void);

static void Poll_VCU(void);

static void Process_Command(
    uint8_t mode,
    uint8_t value
);

static void Read_Fault_Input(void);

static void Update_Motor_State(void);

static void Apply_PWM(
    uint8_t percent
);

static void Send_Health(void);

static void Print_Status(void);

/* -------------------------------------------------------------------------- */
/* TEXT                                                                       */
/* -------------------------------------------------------------------------- */

static const char *Motor_Mode_Text(
    Motor_Mode_t mode
)
{
    switch (mode)
    {
        case MOTOR_STOP:
            return "STOP";

        case MOTOR_DRIVE:
            return "DRIVE";

        case MOTOR_REGEN:
            return "REGEN";

        case MOTOR_FAULT:
            return "FAULT";

        default:
            return "UNKNOWN";
    }
}

/* -------------------------------------------------------------------------- */
/* DIRECT USART2 RX                                                           */
/* -------------------------------------------------------------------------- */

static void Poll_VCU(void)
{
    static uint8_t waiting_for_value = 0;
    static uint8_t mode = 'S';

    while (__HAL_UART_GET_FLAG(&huart2, UART_FLAG_RXNE))
    {
        uint8_t rx =
            (uint8_t)(huart2.Instance->DR & 0xFFU);

        if (!waiting_for_value)
        {
            if (
                (rx == 'D') ||
                (rx == 'R') ||
                (rx == 'S')
               )
            {
                mode = rx;

                waiting_for_value = 1;
            }
        }

        else
        {
            received_mode = mode;

            received_value = rx;

            Process_Command(
                received_mode,
                received_value
            );

            waiting_for_value = 0;
        }
    }
}

/* -------------------------------------------------------------------------- */
/* PROCESS COMMAND                                                            */
/* -------------------------------------------------------------------------- */

static void Process_Command(
    uint8_t mode,
    uint8_t value
)
{
    if (value > 100U)
    {
        value = 100U;
    }

    if (hardware_fault)
    {
        return;
    }

    if (mode == 'D')
    {
        motor_mode = MOTOR_DRIVE;

        torque_request = value;

        regen_request = 0;
    }

    else if (mode == 'R')
    {
        motor_mode = MOTOR_REGEN;

        torque_request = 0;

        regen_request = value;
    }

    else
    {
        motor_mode = MOTOR_STOP;

        torque_request = 0;

        regen_request = 0;
    }
}

/* -------------------------------------------------------------------------- */
/* HARDWARE FAULT                                                             */
/* -------------------------------------------------------------------------- */

static void Read_Fault_Input(void)
{
    hardware_fault =
        (
            HAL_GPIO_ReadPin(
                GPIOA,
                GPIO_PIN_4
            )
            ==
            GPIO_PIN_SET
        );
}

/* -------------------------------------------------------------------------- */
/* MOTOR STATE                                                                */
/* -------------------------------------------------------------------------- */

static void Update_Motor_State(void)
{
    if (hardware_fault)
    {
        motor_mode = MOTOR_FAULT;

        torque_request = 0;

        regen_request = 0;

        pwm_percent = 0;

        return;
    }

    if (motor_mode == MOTOR_DRIVE)
    {
        pwm_percent = torque_request;
    }

    else
    {
        /*
         * Regen is only represented logically
         * in this single-MOSFET demo.
         */
        pwm_percent = 0;
    }
}

/* -------------------------------------------------------------------------- */
/* PWM                                                                        */
/* -------------------------------------------------------------------------- */

static void Apply_PWM(
    uint8_t percent
)
{
    if (percent > 100U)
    {
        percent = 100U;
    }

    uint32_t compare =
        ((uint32_t)percent *
         (htim3.Init.Period + 1U))
        / 100U;

    if (compare > htim3.Init.Period)
    {
        compare = htim3.Init.Period;
    }

    __HAL_TIM_SET_COMPARE(
        &htim3,
        TIM_CHANNEL_1,
        compare
    );
}

/* -------------------------------------------------------------------------- */
/* MOTOR -> VCU                                                               */
/* -------------------------------------------------------------------------- */

static void Send_Health(void)
{
    uint8_t status;

    if (hardware_fault)
    {
        status = 'F';
    }
    else
    {
        status = 'O';
    }

    HAL_UART_Transmit(
        &huart2,
        &status,
        1,
        10
    );
}

/* -------------------------------------------------------------------------- */
/* MOTOR SCREEN                                                               */
/* -------------------------------------------------------------------------- */

static void Print_Status(void)
{
    uint8_t dtc =
        hardware_fault ? 1U : 0U;

    snprintf(
        tx_buffer,
        sizeof(tx_buffer),

        "\r\n"
        "AURORA MOTOR CTRL\r\n"
        "MODE: %s\r\n"
        "RX MODE: %c | RX VALUE: %u\r\n"
        "CMD: %u %% | PWM: %u %%\r\n"
        "REGEN: %u %%\r\n"
        "FAULT: %s | DTC: %u\r\n"
        "VCU LINK: OK\r\n"
        "-------------------------\r\n",

        Motor_Mode_Text(motor_mode),

        received_mode,
        received_value,

        torque_request,
        pwm_percent,

        regen_request,

        hardware_fault
            ? "ACTIVE"
            : "NONE",

        dtc
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

    MX_USART1_UART_Init();

    MX_USART2_UART_Init();

    MX_TIM3_Init();

    if (
        HAL_TIM_PWM_Start(
            &htim3,
            TIM_CHANNEL_1
        ) != HAL_OK
       )
    {
        Error_Handler();
    }

    Apply_PWM(0);

    const char startup[] =
        "\r\nAURORA MOTOR CTRL READY\r\n";

    HAL_UART_Transmit(
        &huart1,
        (uint8_t *)startup,
        sizeof(startup) - 1U,
        50
    );

    uint32_t last_health_time = 0;

    uint32_t last_debug_time = 0;

    while (1)
    {
        uint32_t now =
            HAL_GetTick();

        Poll_VCU();

        Read_Fault_Input();

        Update_Motor_State();

        Apply_PWM(
            pwm_percent
        );

        if (
            (now - last_health_time)
            >= 500U
           )
        {
            Send_Health();

            last_health_time =
                now;
        }

        if (
            (now - last_debug_time)
            >= 1000U
           )
        {
            Print_Status();

            last_debug_time =
                now;
        }

        HAL_Delay(2);
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

    /* PA4 = Motor fault input */

    GPIO_InitStruct.Pin =
        GPIO_PIN_4;

    GPIO_InitStruct.Mode =
        GPIO_MODE_INPUT;

    GPIO_InitStruct.Pull =
        GPIO_PULLDOWN;

    HAL_GPIO_Init(
        GPIOA,
        &GPIO_InitStruct
    );

    /* PA2 TX / PA3 RX = USART2 VCU link */

    GPIO_InitStruct.Pin =
        GPIO_PIN_2 |
        GPIO_PIN_3;

    GPIO_InitStruct.Mode =
        GPIO_MODE_AF_PP;

    GPIO_InitStruct.Pull =
        GPIO_NOPULL;

    GPIO_InitStruct.Speed =
        GPIO_SPEED_FREQ_LOW;

    GPIO_InitStruct.Alternate =
        GPIO_AF7_USART2;

    HAL_GPIO_Init(
        GPIOA,
        &GPIO_InitStruct
    );

    /* PA9 = USART1 debug screen */

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

    /* PA6 = TIM3_CH1 */

    GPIO_InitStruct.Pin =
        GPIO_PIN_6;

    GPIO_InitStruct.Mode =
        GPIO_MODE_AF_PP;

    GPIO_InitStruct.Pull =
        GPIO_NOPULL;

    GPIO_InitStruct.Speed =
        GPIO_SPEED_FREQ_LOW;

    GPIO_InitStruct.Alternate =
        GPIO_AF2_TIM3;

    HAL_GPIO_Init(
        GPIOA,
        &GPIO_InitStruct
    );
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
/* USART2 VCU LINK                                                            */
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
        UART_MODE_TX_RX;

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
/* TIM3 HARDWARE PWM                                                          */
/* -------------------------------------------------------------------------- */

static void MX_TIM3_Init(void)
{
    TIM_OC_InitTypeDef sConfigOC =
        {0};

    __HAL_RCC_TIM3_CLK_ENABLE();

    htim3.Instance =
        TIM3;

    htim3.Init.Prescaler =
        79;

    htim3.Init.CounterMode =
        TIM_COUNTERMODE_UP;

    htim3.Init.Period =
        999;

    htim3.Init.ClockDivision =
        TIM_CLOCKDIVISION_DIV1;

    htim3.Init.AutoReloadPreload =
        TIM_AUTORELOAD_PRELOAD_DISABLE;

    if (
        HAL_TIM_PWM_Init(
            &htim3
        ) != HAL_OK
       )
    {
        Error_Handler();
    }

    sConfigOC.OCMode =
        TIM_OCMODE_PWM1;

    sConfigOC.Pulse =
        0;

    sConfigOC.OCPolarity =
        TIM_OCPOLARITY_HIGH;

    sConfigOC.OCFastMode =
        TIM_OCFAST_DISABLE;

    if (
        HAL_TIM_PWM_ConfigChannel(
            &htim3,
            &sConfigOC,
            TIM_CHANNEL_1
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
