//=========================================================================
// riscv-lab3test.S
//=========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //-----------------------------------------------------------------
        // WAW Hazard Tests
        //-----------------------------------------------------------------

        // Test regular WAW hazard with different values
        TEST_RR_OP( mul, 5, 4, 20 )       // First instruction writing to x4
        TEST_RR_OP( mul, 6, 3, 18 )       // Second instruction writing to x4
        
        // Test WAW with source equal to destination
        TEST_RR_SRCS_EQ_DEST( mul, 5, 25 )  // x2 = x2 * x2
        TEST_RR_SRCS_EQ_DEST( mul, 6, 36 )  // Same destination register

        //-----------------------------------------------------------------
        // Two Non-ALU Instructions Test
        //-----------------------------------------------------------------

        // Test two multiply instructions
        TEST_RR_OP( mul, 7, 6, 42 )       // First multiply
        TEST_RR_OP( mul, 8, 5, 40 )       // Second multiply

        // Test multiply followed by divide
        TEST_RR_OP( mul,  10, 5, 50 )     // Multiply first
        TEST_RR_OP( div,  50, 5, 10 )     // Divide using previous result


        TEST_RISCV_END

