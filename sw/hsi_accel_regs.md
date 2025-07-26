<!-- hsi_accel_registers.md -->

<table class="regdef" id="Reg_opcode">
  <tr>
    <th class="regdef" colspan="5">
      <div>hsi_accel.OP_CODE @ 0x0</div>
      <div><p>Operation code for the HSI accelerator (0 = dot‑product; 1 = cross‑product; others reserved).</p></div>
      <div>Reset default = 0x0, mask 0xFFFFFFFF</div>
    </th>
  </tr>
  <tr>
    <td colspan="5">
      <table class="regpic">
        <tr>
          <td class="bitnum">31</td><td class="bitnum">30</td><td class="bitnum">29</td><td class="bitnum">28</td>
          <td class="bitnum">27</td><td class="bitnum">26</td><td class="bitnum">25</td><td class="bitnum">24</td>
          <td class="bitnum">23</td><td class="bitnum">22</td><td class="bitnum">21</td><td class="bitnum">20</td>
          <td class="bitnum">19</td><td class="bitnum">18</td><td class="bitnum">17</td><td class="bitnum">16</td>
        </tr>
        <tr><td class="unused" colspan="16">&nbsp;</td></tr>
        <tr>
          <td class="bitnum">15</td><td class="bitnum">14</td><td class="bitnum">13</td><td class="bitnum">12</td>
          <td class="bitnum">11</td><td class="bitnum">10</td><td class="bitnum">9</td><td class="bitnum">8</td>
          <td class="bitnum">7</td><td class="bitnum">6</td><td class="bitnum">5</td><td class="bitnum">4</td>
          <td class="bitnum">3</td><td class="bitnum">2</td><td class="bitnum">1</td><td class="bitnum">0</td>
        </tr>
        <tr><td class="unused" colspan="32">&nbsp;</td></tr>
        <tr><td class="fname" colspan="32">OP_CODE</td></tr>
      </table>
    </td>
  </tr>
  <tr>
    <th width="5%">Bits</th>
    <th width="5%">Type</th>
    <th width="5%">Reset</th>
    <th>Name</th>
    <th>Description</th>
  </tr>
  <tr>
    <td class="regbits">31:0</td>
    <td class="regperm">rw</td>
    <td class="regrv">0x0</td>
    <td class="regfn">OP_CODE</td>
    <td class="regde"><p>Operation code. 0 = dot‑product; 1 = cross‑product; other values reserved.</p></td>
  </tr>
</table>

<br>

<table class="regdef" id="Reg_num_bands">
  <tr>
    <th class="regdef" colspan="5">
      <div>hsi_accel.NUM_BANDS @ 0x4</div>
      <div><p>Number of spectral bands to process.</p></div>
      <div>Reset default = 0x0, mask 0xFFFFFFFF</div>
    </th>
  </tr>
  <tr>
    <td colspan="5">
      <table class="regpic">
        <tr>
          <td class="bitnum">31</td><td class="bitnum">30</td><td class="bitnum">29</td><td class="bitnum">28</td>
          <td class="bitnum">27</td><td class="bitnum">26</td><td class="bitnum">25</td><td class="bitnum">24</td>
          <td class="bitnum">23</td><td class="bitnum">22</td><td class="bitnum">21</td><td class="bitnum">20</td>
          <td class="bitnum">19</td><td class="bitnum">18</td><td class="bitnum">17</td><td class="bitnum">16</td>
        </tr>
        <tr><td class="unused" colspan="16">&nbsp;</td></tr>
        <tr>
          <td class="bitnum">15</td><td class="bitnum">14</td><td class="bitnum">13</td><td class="bitnum">12</td>
          <td class="bitnum">11</td><td class="bitnum">10</td><td class="bitnum">9</td><td class="bitnum">8</td>
          <td class="bitnum">7</td><td class="bitnum">6</td><td class="bitnum">5</td><td class="bitnum">4</td>
          <td class="bitnum">3</td><td class="bitnum">2</td><td class="bitnum">1</td><td class="bitnum">0</td>
        </tr>
        <tr><td class="unused" colspan="32">&nbsp;</td></tr>
        <tr><td class="fname" colspan="32">NUM_BANDS</td></tr>
      </table>
    </td>
  </tr>
  <tr>
    <th>Bits</th><th>Type</th><th>Reset</th><th>Name</th><th>Description</th>
  </tr>
  <tr>
    <td class="regbits">31:0</td>
    <td class="regperm">rw</td>
    <td class="regrv">0x0</td>
    <td class="regfn">NUM_BANDS</td>
    <td class="regde"><p>Number of bands in the input vectors. Valid range: 1…MAX_BANDS.</p></td>
  </tr>
</table>

<br>

<table class="regdef" id="Reg_command">
  <tr>
    <th class="regdef" colspan="5">
      <div>hsi_accel.COMMAND @ 0x8</div>
      <div><p>Command register: START operation; clear flags.</p></div>
      <div>Reset default = 0x0, mask 0x7</div>
    </th>
  </tr>
  <tr>
    <td colspan="5">
      <table class="regpic">
        <tr>
          <td class="bitnum">31</td><td class="bitnum">30</td><td class="bitnum">29</td><td class="bitnum">28</td>
          <td class="bitnum">27</td><td class="bitnum">26</td><td class="bitnum">25</td><td class="bitnum">24</td>
          <td class="bitnum">23</td><td class="bitnum">22</td><td class="bitnum">21</td><td class="bitnum">20</td>
          <td class="bitnum">19</td><td class="bitnum">18</td><td class="bitnum">17</td><td class="bitnum">16</td>
        </tr>
        <tr><td class="unused" colspan="16">&nbsp;</td></tr>
        <tr>
          <td class="bitnum">15</td><td class="bitnum">14</td><td class="bitnum">13</td><td class="bitnum">12</td>
          <td class="bitnum">11</td><td class="bitnum">10</td><td class="bitnum">9</td><td class="bitnum">8</td>
          <td class="bitnum">7</td><td class="bitnum">6</td><td class="bitnum">5</td><td class="bitnum">4</td>
          <td class="bitnum">3</td><td class="bitnum">2</td><td class="bitnum">1</td><td class="bitnum">0</td>
        </tr>
        <tr><td class="unused" colspan="13">&nbsp;</td>
            <td class="fname" colspan="1" style="font-size:80%;">CLEAR_ERROR</td>
            <td class="fname" colspan="1" style="font-size:80%;">CLEAR_DONE</td>
            <td class="fname" colspan="1" style="font-size:80%;">START</td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <th>Bits</th><th>Type</th><th>Reset</th><th>Name</th><th>Description</th>
  </tr>
  <tr>
    <td class="regbits">0</td><td class="regperm">wo</td><td class="regrv">0x0</td>
    <td class="regfn">START</td>
    <td class="regde"><p>Writing 1 launches the operation. Self-clears.</p></td>
  </tr>
  <tr>
    <td class="regbits">1</td><td class="regperm">wo</td><td class="regrv">0x0</td>
    <td class="regfn">CLEAR_DONE</td>
    <td class="regde"><p>Writing 1 clears the DONE flag. Self-clears.</p></td>
  </tr>
  <tr>
    <td class="regbits">2</td><td class="regperm">wo</td><td class="regrv">0x0</td>
    <td class="regfn">CLEAR_ERROR</td>
    <td class="regde"><p>Writing 1 clears the ERROR_CODE bits. Self-clears.</p></td>
  </tr>
</table>

<br>

<table class="regdef" id="Reg_status">
  <tr>
    <th class="regdef" colspan="5">
      <div>hsi_accel.STATUS @ 0xC</div>
      <div><p>Status register: DONE, ERROR_CODE, BUSY.</p></div>
      <div>Reset default = 0x0, mask 0x10F</div>
    </th>
  </tr>
  <tr>
    <td colspan="5">
      <table class="regpic">
        <tr>
          <td class="bitnum">31</td><td class="bitnum">30</td><td class="bitnum">29</td><td class="bitnum">28</td>
          <td class="bitnum">27</td><td class="bitnum">26</td><td class="bitnum">25</td><td class="bitnum">24</td>
          <td class="bitnum">23</td><td class="bitnum">22</td><td class="bitnum">21</td><td class="bitnum">20</td>
          <td class="bitnum">19</td><td class="bitnum">18</td><td class="bitnum">17</td><td class="bitnum">16</td>
        </tr>
        <tr><td class="unused" colspan="16">&nbsp;</td></tr>
        <tr>
          <td class="bitnum">15</td><td class="bitnum">14</td><td class="bitnum">13</td><td class="bitnum">12</td>
          <td class="bitnum">11</td><td class="bitnum">10</td><td class="bitnum">9</td><td class="bitnum">8</td>
          <td class="bitnum">7</td><td class="bitnum">6</td><td class="bitnum">5</td><td class="bitnum">4</td>
          <td class="bitnum">3</td><td class="bitnum">2</td><td class="bitnum">1</td><td class="bitnum">0</td>
        </tr>
        <tr><td class="unused" colspan="7">&nbsp;</td>
            <td class="fname" colspan="1">BUSY</td>
            <td class="unused" colspan="4">&nbsp;</td>
            <td class="fname" colspan="3">ERROR_CODE</td>
            <td class="fname" colspan="1">DONE</td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <th>Bits</th><th>Type</th><th>Reset</th><th>Name</th><th>Description</th>
  </tr>
  <tr>
    <td class="regbits">0</td><td class="regperm">ro</td><td class="regrv">0x0</td>
    <td class="regfn">DONE</td>
    <td class="regde"><p>Set when operation completes. Cleared by writing CLEAR_DONE.</p></td>
  </tr>
  <tr>
    <td class="regbits">3:1</td><td class="regperm">ro</td><td class="regrv">0x0</td>
    <td class="regfn">ERROR_CODE</td>
    <td class="regde"><p>Error status code. 0 = no error; nonzero indicates failure. Cleared by CLEAR_ERROR.</p></td>
  </tr>
  <tr>
    <td class="regbits">8</td><td class="regperm">ro</td><td class="regrv">0x0</td>
    <td class="regfn">BUSY</td>
    <td class="regde"><p>Set while operation is in progress.</p></td>
  </tr>
</table>
