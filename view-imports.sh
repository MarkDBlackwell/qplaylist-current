#!/bin/sh

grep -r @import build/website \
| ruby -e "s=':@import url(\"..';
puts readlines.map{|e| e.chomp.chop \
.sub('build/website/','')
.sub('\")','') \
.sub(s,' | ')} \
.sort" \
| kwrite --stdin &

grep -r @import build/website \
| ruby -e "s=':@import url(\"..';
puts readlines.map{|e| e.chomp.chop \
.sub('build/website/','')
.sub('\")','') \
.split(s) \
.reverse.join(' | ')} \
.sort" \
| kwrite --stdin &
