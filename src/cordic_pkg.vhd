-- SPDX-License-Identifier: MIT
-- =============================================================================
-- Title       : CORDIC Package (types, constants, angle table)
-- File        : cordic_pkg.vhd
-- Author      : Abhishek Garg <abhishekgarg403@gmail.com>
-- Created     : 2025-08-15
-- Last Edited : 2025-08-15
-- Version     : 1.0
-- -----------------------------------------------------------------------------
-- Description :
--   Shared types, fixed-point helper functions, constant definitions, and
--   precomputed CORDIC angle table. Put package-level constants such as:
--     - WORD_WIDTH, FRACTION_BITS
--     - ITERATIONS
--     - CORDIC_K (scaling factor)
--     - ANGLE_TABLE : array(0 to ITER-1) of signed(WF-1 downto 0)
--
-- -----------------------------------------------------------------------------
-- Contents (suggested)
--   - subtype sfixed_t is signed(WF-1 downto 0);
--   - constant ITERATIONS : integer := 16;
--   - constant ANGLE_TABLE : array(0 to ITERATIONS-1) of sfixed_t := ( ... );
--   - function to_sfixed(real) return sfixed_t;     -- optional helpers
--   - function wrap_phase(sfixed_t) return sfixed_t;
--
-- -----------------------------------------------------------------------------
-- Implementation notes :
--   - Precompute angle table values with high precision (e.g., Python)
--     and place them here as hex or signed binary literals.
--   - Document the fixed point format clearly (e.g., Q1.(WF-1) or Qm.f)
--   - Keep package synthesis-friendly (avoid floating point ops inside)
--
-- -----------------------------------------------------------------------------
-- Revision History :
--   v1.0  2025-08-15  Initial release
--
-- -----------------------------------------------------------------------------
-- License :
--   Released under the MIT License.
-- =============================================================================


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package cordic_pkg is
  constant CORDIC_WIDTH          : integer := 16;  -- I/O bit width
  constant CORDIC_FRAC           : integer := 14;
  constant CORDIC_GAIN           : real := 0.607252935;
  constant CORDIC_INTERNAL_WIDTH : integer := 32;  -- Wider internal width
  constant MATH_PI      	     : real := 3.141592653589793;
  constant CORDIC_INT          : integer := 2;
  
  
  subtype sfixed_t         is signed(CORDIC_WIDTH-1 downto 0);
  subtype sfixed_internal_t is signed(CORDIC_INTERNAL_WIDTH-1 downto 0);

  type angle_lut_t is array (natural range <>) of sfixed_internal_t;
  
  function gen_atan_table(N : integer) return angle_lut_t;
  function real_to_sfixed(val : real; width : integer := CORDIC_INTERNAL_WIDTH) return signed;
  function fixed_mul(a, b : sfixed_t) return sfixed_internal_t;
  function sfixed_to_real(val : sfixed_t) return real;
  function signed_to_sfixed_t(val : signed) return sfixed_t;
  function slv_to_string(slv : std_logic_vector) return string;
  constant SFIXED_PI    		 : sfixed_internal_t := real_to_sfixed(MATH_PI,CORDIC_INTERNAL_WIDTH);
  constant SFIXED_TWO_PI: sfixed_internal_t := real_to_sfixed(2.0 * MATH_PI,CORDIC_INTERNAL_WIDTH);
  constant ANGLES : angle_lut_t := gen_atan_table(32);  -- Extra entries for safety
  constant SFIXED_TWO_PI_S : sfixed_t := resize(SFIXED_TWO_PI, CORDIC_WIDTH);
  constant SFIXED_ZERO     : sfixed_internal_t := real_to_sfixed(0.0, CORDIC_INTERNAL_WIDTH);
  constant SFIXED_PI_OVER_2 : sfixed_internal_t := real_to_sfixed(MATH_PI / 2.0,CORDIC_INTERNAL_WIDTH);

end package;

package body cordic_pkg is
  function gen_atan_table(N : integer) return angle_lut_t is
    variable tbl : angle_lut_t(0 to N-1);
    constant scale : real := 2.0 ** CORDIC_FRAC;
  begin
    for i in 0 to N-1 loop
      tbl(i) := to_signed(integer(round(arctan(1.0 / (2.0**i)) * scale)), CORDIC_INTERNAL_WIDTH);
    end loop;
    return tbl;
  end;

  function real_to_sfixed(val : real; width : integer := CORDIC_INTERNAL_WIDTH) return signed is
	  variable temp : integer;
	begin
	  temp := integer(round(val * 2.0**CORDIC_FRAC));
	  return to_signed(temp, width);
	end function;

  
  function fixed_mul(a, b : sfixed_internal_t) return sfixed_internal_t is
	  variable temp : signed(a'length + b'length - 1 downto 0);
	  variable result : sfixed_internal_t;
	begin
	  temp := a * b;
	  result := resize(temp(temp'high downto temp'high - CORDIC_INTERNAL_WIDTH + 1), CORDIC_INTERNAL_WIDTH);
	  return result;
	end function;

	
	function signed_to_sfixed_t(val : signed) return sfixed_t is
	  variable temp : sfixed_t;
	begin
	  temp := resize(val, CORDIC_WIDTH);
	  return temp;
	end function;
	
	function sfixed_to_real(val : sfixed_t) return real is
	begin
	  return real(to_integer(val)) / real(2 ** CORDIC_FRAC);
	end function;
	
	function slv_to_string(slv : std_logic_vector) return string is
	  variable result : string(1 to slv'length);
	begin
	  for i in slv'range loop
		if slv(i) = '1' then
		  result(i - slv'low + 1) := '1';
		else
		  result(i - slv'low + 1) := '0';
		end if;
	  end loop;
	  return result;
	end function;



end package body;
