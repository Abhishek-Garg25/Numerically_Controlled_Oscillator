-- SPDX-License-Identifier: MIT
-- =============================================================================
-- Title       : CORDIC Pipelined
-- File        : cordic_pipelined.vhd
-- Author      : Abhishek Garg <abhishekgarg403@gmail.com>
-- Created     : 2025-08-15
-- Last Edited : 2025-08-15
-- Version     : 1.0
-- Repository  : https://github.com/Abhishek-Garg25/cordic-oscillator
-- -----------------------------------------------------------------------------
-- Description :
--   Pipelined implementation of the CORDIC (Coordinate Rotation Digital
--   Computer) algorithm. This module supports both "ROTATION" and "VECTORING"
--   modes (selected via the MODE generic), and processes the input vector and
--   angle across multiple fully-pipelined stages.
--
--   The design includes:
--     - Initial quadrant detection and angle mapping into ±?/2
--     - Iterative micro-rotations using the cordic_stage entity
--     - Final output correction based on quadrant
--     - Registered valid signal propagation for streaming operation
--
-- -----------------------------------------------------------------------------
-- Generics :
--   MODE   : string  := "ROTATION"
--       Algorithm mode:
--         "ROTATION"  - Rotate input vector by given angle
--         "VECTORING" - Compute magnitude and angle of input vector
--
--   STAGES : integer := 16
--       Number of pipeline stages (iterations). Controls precision,
--       latency, and resource usage.
--
-- -----------------------------------------------------------------------------
-- Ports :
--   clk        : in  std_logic
--       System clock.
--
--   rst        : in  std_logic
--       Synchronous active-high reset.
--
--   valid_in   : in  std_logic
--       Input data valid strobe.
--
--   x_in, y_in : in  sfixed_t
--       Fixed-point X and Y vector inputs.
--
--   z_in       : in  sfixed_internal_t
--       Fixed-point angle input (ROTATION mode) or initial Z accumulator
--       (VECTORING mode).
--
--   valid_out  : out std_logic
--       Output data valid strobe (aligned with x_out/y_out/z_out).
--
--   x_out, y_out : out sfixed_t
--       Fixed-point rotated vector components (or magnitude + sign).
--
--   z_out     : out sfixed_t
--       Fixed-point updated angle (ROTATION mode) or computed phase
--       (VECTORING mode).
--
-- -----------------------------------------------------------------------------
-- Dependencies :
--   - work.cordic_pkg     : Fixed-point type definitions, constants, angle table
--   - work.cordic_stage   : Single CORDIC micro-rotation stage
--
-- -----------------------------------------------------------------------------
-- Implementation notes :
--   - The first stage performs quadrant detection and remaps the phase into
--     ±?/2 for convergence.
--   - The CORDIC pipeline is unrolled using a generate loop.
--   - Valid and quadrant signals are delayed through matching pipeline
--     registers to maintain alignment.
--   - Final stage applies quadrant-based sign correction to outputs.
--   - Latency = STAGES + 1 cycles from valid_in to valid_out.
--
-- -----------------------------------------------------------------------------
-- Revision History :
--   v1.0  2025-08-15  Initial release
--
-- -----------------------------------------------------------------------------
-- License :
--   Released under the MIT License. See LICENSE file in the project root.
-- =============================================================================


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cordic_pkg.all;
use ieee.math_real.all;


entity cordic_pipelined is
  generic (
    MODE   : string := "ROTATION";
    STAGES : integer := 16
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    valid_in   : in  std_logic;
    x_in, y_in : in  sfixed_t;
    z_in       : in sfixed_internal_t;
    valid_out  : out std_logic;
    x_out, y_out, z_out : out sfixed_t
  );
end entity;

architecture rtl of cordic_pipelined is

  type pipe_array_t is array (natural range <>) of sfixed_internal_t;
  signal x_pipe, y_pipe, z_pipe : pipe_array_t(0 to STAGES);
  signal valid_pipe : std_logic_vector(0 to STAGES);

  type quadrant_array_t is array (natural range <>) of unsigned(1 downto 0);
  signal quadrant_stages : quadrant_array_t(0 to STAGES);

  signal x_corrected, y_corrected : sfixed_internal_t;

begin

  --------------------------------------------------------------------
  -- Stage 0: Quadrant detection + phase mapping into ±?/2
  --------------------------------------------------------------------
  process(clk)
    variable z_internal : sfixed_internal_t;
    variable z_wrapped  : sfixed_internal_t;
    variable k : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        x_pipe(0)          <= (others => '0');
        y_pipe(0)          <= (others => '0');
        z_pipe(0)          <= (others => '0');
        quadrant_stages(0) <= "00";
        valid_pipe(0)      <= '0';
      else
        -- Convert z_in to internal width
        z_internal := resize(z_in, CORDIC_INTERNAL_WIDTH);

        ----------------------------------------------------------------
        -- Wrap into -? … ? (to handle overflow)
        ----------------------------------------------------------------
        z_wrapped := z_internal;
--        while z_wrapped > SFIXED_PI loop
--          z_wrapped := z_wrapped - SFIXED_TWO_PI;
--        end loop;
--        while z_wrapped <= -SFIXED_PI loop
--          z_wrapped := z_wrapped + SFIXED_TWO_PI;
--        end loop;
        -- assuming z_wrapped, SFIXED_PI, SFIXED_TWO_PI are of the same sfixed type
        if z_wrapped > SFIXED_PI then
            z_wrapped := z_wrapped - SFIXED_TWO_PI;
        elsif z_wrapped <= -SFIXED_PI then
            z_wrapped := z_wrapped + SFIXED_TWO_PI;
        end if;

        

        ----------------------------------------------------------------
        -- Quadrant detection
        ----------------------------------------------------------------
        if    z_wrapped >= SFIXED_ZERO and z_wrapped <= SFIXED_PI_OVER_2 then
          -- Q1: 0 ? +?/2
          quadrant_stages(0) <= "00";
          z_pipe(0) <= z_wrapped;

        elsif z_wrapped > SFIXED_PI_OVER_2 and (z_wrapped <= SFIXED_PI or z_wrapped >= -SFIXED_PI_OVER_2) then
          -- Q2: +?/2 ? ?
          quadrant_stages(0) <= "01";
          z_pipe(0) <= SFIXED_PI - z_wrapped;

        elsif z_wrapped < SFIXED_ZERO and z_wrapped >= -SFIXED_PI_OVER_2 then
          -- Q4: -?/2 ? 0
          quadrant_stages(0) <= "11";
          z_pipe(0) <= -z_wrapped;

        else
          -- Q3: -? ? -?/2
          quadrant_stages(0) <= "10";
          z_pipe(0) <= -(SFIXED_PI + z_wrapped);
        end if;

        ----------------------------------------------------------------
        -- Pipe input values
        ----------------------------------------------------------------
        x_pipe(0)     <= resize(x_in, CORDIC_INTERNAL_WIDTH);
        y_pipe(0)     <= resize(y_in, CORDIC_INTERNAL_WIDTH);
        valid_pipe(0) <= valid_in;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- CORDIC pipeline stages
  --------------------------------------------------------------------
  gen_stages: for i in 0 to STAGES - 1 generate
    stage_inst: entity work.cordic_stage
      generic map (
        ITERATION => i,
        MODE => MODE
      )
      port map (
        clk   => clk,
        x_in  => x_pipe(i),
        y_in  => y_pipe(i),
        z_in  => z_pipe(i),
        x_out => x_pipe(i+1),
        y_out => y_pipe(i+1),
        z_out => z_pipe(i+1)
      );

    -- Delay valid and quadrant signals in sync with pipeline
    stage_ctrl: process(clk)
    begin
      if rising_edge(clk) then
        valid_pipe(i+1)      <= valid_pipe(i);
        quadrant_stages(i+1) <= quadrant_stages(i);
      end if;
    end process;
  end generate;

  --------------------------------------------------------------------
  -- Final output correction based on quadrant
  --------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      case quadrant_stages(STAGES) is
        when "00" => -- Q1
          x_corrected <= x_pipe(STAGES);
          y_corrected <= y_pipe(STAGES);

        when "01" => -- Q2
          x_corrected <= -x_pipe(STAGES);
          y_corrected <= y_pipe(STAGES);

        when "10" => -- Q3
          x_corrected <= -x_pipe(STAGES);
          y_corrected <= y_pipe(STAGES);

        when "11" => -- Q4
          x_corrected <= x_pipe(STAGES);
          y_corrected <= -y_pipe(STAGES);

        when others =>
          x_corrected <= (others => '0');
          y_corrected <= (others => '0');
      end case;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Registered outputs
  --------------------------------------------------------------------
  x_out <= resize(x_corrected, CORDIC_WIDTH);
  y_out <= resize(y_corrected, CORDIC_WIDTH);
  z_out <= resize(z_pipe(STAGES), CORDIC_WIDTH);
  valid_out <= valid_pipe(STAGES);

end architecture;
