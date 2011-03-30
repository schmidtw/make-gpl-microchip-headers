#!/bin/bash

# Usage: to_csv.sh filename sfr_first_page sfr_last_page config_first_page config_last_page
echo "--info--";
echo "document:";
echo "sfr-pages:$2-$3";
echo "sfr-register-size:8";
echo "config-pages:$4-$5";
echo "config-register-size:8";
echo "--sfr--";
pdftohtml -xml -stdout -i -q -nomerge -f $2 -l $3 $1 | perl ./page_to_file.pl $6
echo "--config--";
pdftohtml -xml -stdout -i -q -nomerge -f $4 -l $5 $1 | perl ./page_to_file.pl
