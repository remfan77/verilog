module top_module (input clk, input tx_start, output tx_pin, input rx_pin, output w_led_ale);

    reg [7:0] rx_char;
    reg [7:0] tx_char = 8'h60;
    wire [7:0] w_rx_char;
    reg[22:0] r_cnt_led_ale;
    wire w_rx_done;
    reg r_rx_done;
    wire w_slow_clk;
    reg r_tx_start;

   start_tx_manag(.clk(clk),
                  .slow_clk(w_slow_clk));

    uart_tx ut (.clk(clk),
                .start_tx(w_slow_clk), //tx_start),
                .out(tx_pin),
                .w_out_ff(tx_char));

    uart_rx urx(.clk(clk),
                .rx_char(w_rx_char),
                .rx_pin(rx_pin),
                .wo_rx_done(w_rx_done));
    
    always @(posedge clk)
    begin
       rx_char <= w_rx_char;
       r_rx_done <= w_rx_done;
       if (r_rx_done)
        tx_char <= (tx_start ? tx_char + 1 : w_rx_char); 

       r_cnt_led_ale <= r_cnt_led_ale + 1;
    end

    assign w_led_ale = r_cnt_led_ale[21];

endmodule

module start_tx_manag(input clk, output slow_clk);
    reg [20:0] counter;
    reg go;
    always @(posedge clk)
    begin
      counter <= counter + 1;
      if (counter == 0)
        go <= 1;
      else
        go <= 0;
    end
    assign slow_clk = go;
endmodule

module uart_rx(input clk, output [7:0] rx_char, input rx_pin, output wo_rx_done);
    reg[31:0] t = 0;
    reg[31:0] t_sampling = 0;
    reg[7:0]  state_rx = 0;
    reg[7:0]  r_rx_char = 8'h41;
    reg r_rx_done;

    always @(posedge clk)
    begin
        t <= t + 1;
        case (state_rx)
        0:  begin
               r_rx_done <= 0;
               if (rx_pin == 0)
               begin
                 state_rx <= 1;
                 t_sampling <= t + (117*2 * 3) / 2;
              end
            end
        1,2,3,4,5,6,7,8:
              if (t == t_sampling)
              begin
                state_rx <= state_rx + 8'h01;
                t_sampling <= t_sampling + 117*2;
                r_rx_char <= (r_rx_char >> 1) | (rx_pin << 7);
              end
        9:
              if (t == t_sampling)
              begin
                r_rx_done <=  1;
                state_rx <= 0;
              end
        endcase
     end
     assign rx_char = r_rx_char;
     assign wo_rx_done = r_rx_done;
endmodule

module uart_tx(input clk, input start_tx, output out, input [7:0] w_out_ff);
    reg[7:0] out_ff;
    reg[4:0] counter = 0;
    reg tx;
    reg [31:0] t;
    reg [31:0] t_sampling;
   
    always @(posedge clk)
        begin
            t <= t + 1;
            case (counter)
            0: if (start_tx)
               begin
                  tx <= 0;
                  counter <= 1;
                  out_ff <= w_out_ff; // 16'h55;
                  t_sampling <= t + 117 * 2;
               end
               else
                  tx <= 1;  // idle

            1,2,3,4,5,6,7,8:
                    if (t == t_sampling)
                    begin
                      tx <= out_ff[0];
                   out_ff <= out_ff >> 1;
                      counter <= counter + 4'h01;
                      t_sampling <= t + 117 * 2;
                    end
            9: if (t == t_sampling)
                begin
                     tx <= 1; // bit di stop
                     counter <= 10;
                     t_sampling <= t + 117 * 2;
                end
           10: if (t == t_sampling)
                begin
                     counter <= 0;
                end
            endcase
        end
   
    assign out = tx;

endmodule