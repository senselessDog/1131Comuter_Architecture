#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        #------------------------------------------------------------------
        # Basic Read Hit Test
        #------------------------------------------------------------------
        
        # Initialize base address for testing
        li    x2, 0x2000    # Base address in data section
        
        # Test 1: Sequential read hits within same cache line
        lw    x3, 0(x2)     # First word read - should miss
        lw    x4, 4(x2)     # Second word read - should hit
        lw    x5, 8(x2)     # Third word read - should hit
        lw    x6, 12(x2)    # Fourth word read - should hit

        #------------------------------------------------------------------
        # Write Hit Test  
        #------------------------------------------------------------------
        
        # Test 2: Write then read from same location
        li    x6, 0xdeadbeef
        sw    x6, 0(x2)     # Write data
        lw    x7, 0(x2)     # Should hit and return written data
        TEST_CHECK_EQ(x7, 0xdeadbeef)

        #------------------------------------------------------------------
        # Read Miss Test with Clean Eviction
        #------------------------------------------------------------------
        
        # Test 3: Access different cache sets
        li    x2, 0x4000    # New base address
        lw    x3, 0(x2)     # Should miss and fetch new line
        
        #------------------------------------------------------------------
        # Write Miss Test with Dirty Eviction
        #------------------------------------------------------------------
        
        # Test 4: Write to location that will cause eviction
        li    x6, 0xcafebabe
        li    x2, 0x6000    # Address that maps to same set
        sw    x6, 0(x2)     # Should miss, write allocate
        lw    x7, 0(x2)     # Should hit
        TEST_CHECK_EQ(x7, 0xcafebabe)

        #------------------------------------------------------------------
        # Conflict Miss Test
        #------------------------------------------------------------------
        
        # Test 5: Access locations that map to same set
        li    x2, 0x2000
        lw    x3, 0(x2)     # Load first line
        li    x2, 0x2800    # Address that maps to same set
        lw    x4, 0(x2)     # Should evict first line
        li    x2, 0x2000    # Return to first address
        lw    x5, 0(x2)     # Should miss again

        #------------------------------------------------------------------
        # Flush Test
        #------------------------------------------------------------------
        
        # Test 6: Write data then trigger flush
        li    x2, 0x2000
        li    x6, 0xabcdef01
        sw    x6, 0(x2)     # Write dirty data
        li    x10, 1        # Value to trigger flush
        csrw  0x7C0, x10    # Write to flush CSR

        # Wait for flush to complete
1:      csrr  x11, 0x7C0
        bnez  x11, 1b
        
        # Verify data after flush
        lw    x7, 0(x2)     # Should miss and fetch flushed data
        TEST_CHECK_EQ(x7, 0xabcdef01)

        TEST_RISCV_END