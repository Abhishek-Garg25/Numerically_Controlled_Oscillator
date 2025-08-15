library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cordic_pkg.all;
use work.cordic_pkg.ANGLES;


entity cordic_stage is
  generic (
    ITERATION : integer := 0;
    MODE      : string := "ROTATION"
  );
  port (
    clk   : in  std_logic;
    x_in  : in  sfixed_internal_t;
    y_in  : in  sfixed_internal_t;
    z_in  : in  sfixed_internal_t;
    x_out : out sfixed_internal_t;
    y_out : out sfixed_internal_t;
    z_out : out sfixed_internal_t
  );
end entity;

architecture rtl of cordic_stage is

  signal x_reg, y_reg, z_reg : sfixed_internal_t;
begin

  process(clk)
    variable dx, dy   : sfixed_internal_t;
    variable angle    : sfixed_internal_t;
    variable sigma    : std_logic;
  begin
    if rising_edge(clk) then
      angle := resize(ANGLES(ITERATION), CORDIC_INTERNAL_WIDTH);

      if MODE = "ROTATION" then
        sigma := z_in(z_in'high);  -- Use sign of angle
      else
        sigma := y_in(y_in'high);  -- Use sign of y for vectoring
      end if;

      dx := ieee.numeric_std.shift_right(y_in, ITERATION);
      dy := ieee.numeric_std.shift_right(x_in, ITERATION);

      if sigma = '0' then
        x_reg <= x_in - dx;
        y_reg <= y_in + dy;
        z_reg <= z_in - angle;
      else
        x_reg <= x_in + dx;
        y_reg <= y_in - dy;
        z_reg <= z_in + angle;
      end if;
    end if;
  end process;

  -- Register output (optional if latency/pipeline match matters)
  x_out <= x_reg;
  y_out <= y_reg;
  z_out <= z_reg;

end architecture;
