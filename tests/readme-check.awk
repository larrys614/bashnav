#  The README is the only page most people will ever read, and a broken
#  one fails silently: GitHub renders it anyway, just wrongly.
#
#  This exists because an unclosed ```sh fence swallowed the lights
#  picture whole.  The <img> tag sat inside the code block, so GitHub
#  showed the tag as text and rendered no image at all - and the report
#  that came back was "the colour still does not show", because from
#  the outside a missing picture and a colourless one look the same.
BEGIN{ fence=0; det=0; bad=0; imgs=0 }
{
  line = $0
  if(line ~ /^```/){ fence = 1 - fence; if(fence) fl = FNR; next }
  if(fence) next                      # inside a fence nothing is markup
  if(line ~ /<details>/)  det++
  if(line ~ /<\/details>/){ det--; if(det<0){ printf "  %d: </details> with nothing open\n", FNR; bad++ } }
  #  An <img> that reaches here is outside every fence, which is the
  #  only place GitHub will render one.
  while(match(line, /<img src="[^"]+"/)){
    s = substr(line, RSTART+10, RLENGTH-11)
    line = substr(line, RSTART+RLENGTH)
    imgs++
    if(s ~ /^https?:/) continue
    if((getline probe < s) < 0){ printf "  %d: <img> points at a file that is not there: %s\n", FNR, s; bad++ }
    close(s)
  }
}
END{
  if(fence){ printf "  %d: a code fence is opened and never closed\n", fl; bad++ }
  if(det>0){ printf "  <details> opened %d time(s) and not closed\n", det; bad++ }
  #  Every picture the README claims to show must actually reach the
  #  reader.  If this number falls, a fence has eaten one again.
  if(imgs < WANT){ printf "  only %d <img> tags render; %d are expected\n", imgs, WANT; bad++ }
  printf "READMERESULT %d %d\n", bad, imgs
}
