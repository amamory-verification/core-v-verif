// 
// Copyright 2020 OpenHW Group
// Copyright 2020 Datum Technology Corporation
// Copyright 2020 Silicon Labs, Inc.
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     https://solderpad.org/licenses/
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

`ifndef __UVMA_INTERRUPT_DRV_SV__
`define __UVMA_INTERRUPT_DRV_SV__

/**
 * Component driving a Clock & Reset virtual interface (uvma_interrupt_if).
 */
class uvma_interrupt_drv_c extends uvm_driver#(
   .REQ(uvma_interrupt_seq_item_c),
   .RSP(uvma_interrupt_seq_item_c)
);
   
   // Objects
   uvma_interrupt_cfg_c    cfg;
   uvma_interrupt_cntxt_c  cntxt;
   
   semaphore               assert_until_ack_sem[32];

   // TLM
   uvm_analysis_port#(uvma_interrupt_seq_item_c)  ap;   
   
   `uvm_component_utils_begin(uvma_interrupt_drv_c)
      `uvm_field_object(cfg  , UVM_DEFAULT)
      `uvm_field_object(cntxt, UVM_DEFAULT)
   `uvm_component_utils_end
   
   /**
    * Default constructor.
    */
   extern function new(string name="uvma_interrupt_drv", uvm_component parent=null);
   
   /**
    * 1. Ensures cfg & cntxt handles are not null.
    * 2. Builds ap.
    */
   extern virtual function void build_phase(uvm_phase phase);
   
   /**
    * Obtains the reqs from the sequence item port and calls drv_req()
    */
   extern virtual task run_phase(uvm_phase phase);
   
   /**
    * Drives the virtual interface's (cntxt.vif) signals using req's contents.
    */
   extern task drv_req(uvma_interrupt_seq_item_c req);
   
   /**
    * Forked thread to handle interrupts
    */
   extern task assert_irq_until_ack(int unsigned index, int unsigned repeat_count);

   /**
    * Assert an interrupt signal
    */
   extern task assert_irq(int unsigned index);

   /**
    * Deassert an interrupt signal
    */
   extern task deassert_irq(int unsigned index);

endclass : uvma_interrupt_drv_c

function uvma_interrupt_drv_c::new(string name="uvma_interrupt_drv", uvm_component parent=null);
   
   super.new(name, parent);
   
endfunction : new


function void uvma_interrupt_drv_c::build_phase(uvm_phase phase);
   
   super.build_phase(phase);
   
   void'(uvm_config_db#(uvma_interrupt_cfg_c)::get(this, "", "cfg", cfg));
   if (!cfg) begin
      `uvm_fatal("CFG", "Configuration handle is null")
   end
   uvm_config_db#(uvma_interrupt_cfg_c)::set(this, "*", "cfg", cfg);
   
   void'(uvm_config_db#(uvma_interrupt_cntxt_c)::get(this, "", "cntxt", cntxt));
   if (!cntxt) begin
      `uvm_fatal("CNTXT", "Context handle is null")
   end
   uvm_config_db#(uvma_interrupt_cntxt_c)::set(this, "*", "cntxt", cntxt);
   
   ap = new("ap", this);
   
   foreach (assert_until_ack_sem[i]) begin
      assert_until_ack_sem[i] = new(1);
   end
endfunction : build_phase


task uvma_interrupt_drv_c::run_phase(uvm_phase phase);
   
   super.run_phase(phase);

   // Enable the driver in the interface
   cntxt.vif.is_active = 1;

   // Whether to drive interrupts from startup
   
   forever begin
      seq_item_port.get_next_item(req);
      `uvml_hrtbt()
      drv_req(req);
      ap.write(req);
      seq_item_port.item_done();
   end
   
endtask : run_phase

task uvma_interrupt_drv_c::drv_req(uvma_interrupt_seq_item_c req);
   `uvm_info("INTERRUPTDRV", $sformatf("Driving:\n%s", req.sprint()), UVM_HIGH);
   case (req.action)
      UVMA_INTERRUPT_SEQ_ITEM_ACTION_ASSERT_UNTIL_ACK: begin
         for (int i = 0; i < 32; i++) begin
            if (req.irq_mask[i]) begin
               automatic int ii = i;
               fork
                  assert_irq_until_ack(ii, req.repeat_count);
               join_none
            end
         end
      end   
      UVMA_INTERRUPT_SEQ_ITEM_ACTION_ASSERT: begin
         for (int i = 0; i < 32; i++) begin
            if (req.irq_mask[i]) begin
               assert_irq(i);
            end
         end
      end   
      UVMA_INTERRUPT_SEQ_ITEM_ACTION_DEASSERT: begin
         for (int i = 0; i < 32; i++) begin
            if (req.irq_mask[i]) begin
               deassert_irq(i);
            end
         end
      end   
   endcase

endtask : drv_req

task uvma_interrupt_drv_c::assert_irq_until_ack(int unsigned index, int unsigned repeat_count);
   // If a thread is already running on this irq, then exit
   if (!assert_until_ack_sem[index].try_get(1))
      return;      

   for (int loop = 0; loop < repeat_count; loop++) begin
      cntxt.vif.drv_cb.irq_drv[index] <= 1'b1;

      while (1) begin
         @(cntxt.vif.mon_cb);
         if ((cntxt.vif.mon_cb.irq_ack && cntxt.vif.mon_cb.irq_id == index) ||
            cntxt.vif.mon_cb.irq_deassert[index])
            break;
      end
   end

   cntxt.vif.drv_cb.irq_drv[index] <= 1'b0;
   assert_until_ack_sem[index].put(1);
endtask : assert_irq_until_ack

task uvma_interrupt_drv_c::assert_irq(int unsigned index);
   cntxt.vif.drv_cb.irq_drv[index] <= 1'b1;
endtask : assert_irq

task uvma_interrupt_drv_c::deassert_irq(int unsigned index);
   if (assert_until_ack_sem[index].try_get(1)) begin
      assert_until_ack_sem[index].put(1);      
      return;      
   end
   
   cntxt.vif.drv_cb.irq_deassert[index] <= 1'b0;
endtask : deassert_irq

`endif // __UVMA_INTERRUPT_DRV_SV__
