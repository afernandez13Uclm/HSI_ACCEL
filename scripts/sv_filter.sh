#!/bin/bash
sed -E \
  -e '/^\s*`(include|timescale).*$/d' \
  -e 's/^\s*import.*::.*;//' \
  -e 's/^\s*parameter.*=.*;//' \
  -e 's/^\s*localparam.*=.*;//' \
  -e 's/\b(logic|wire|reg|bit|byte|shortint|int|longint|integer|time|real|shortreal|enum|struct|union)\b//g' \
  -e 's/#\s*\(.*\)//g' \
  -e '/^\s*generate\s*$/,/^\s*endgenerate\s*$/d' \
  -e '/^\s*always(_ff|_comb|_latch)?\b/,/^\s*end\s*$/d' \
  "$1"
