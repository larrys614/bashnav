#  The README is the only page most people will ever read, and a broken
#  one fails silently: GitHub renders it anyway, just wrongly.
#
#  This exists because an unclosed ```sh fence swallowed the lights
#  picture whole.  The <img> tag sat inside the code block, so GitHub
#  showed the tag as text and rendered no image at all - and the report
#  that came back was "the colour still does not show", because from
#  the outside a missing picture and a colourless one look the same.
#  THE EXPECTED NUMBER OF PICTURES IS DERIVED, NOT TYPED.  It used to
#  arrive as -v WANT=6 from run-tests.sh, and a number typed in two
#  places is the same trap that left three site plates silently empty
#  when make-site.sh named engine versions by hand: the browser-first
#  rewrite took the README from six pictures to two and the check went
#  red for a reason that was not a bug.
#
#  So: count every <img> in the file, fenced or not, and require that all
#  of them render.  That is exactly the fault this check exists for - a
#  fence swallowing a picture leaves the tag in the raw count and out of
#  the rendered one - and it needs no maintenance when a picture is added
#  or removed.
#
#  What it no longer guards is a picture being deleted outright, which
#  the typed WANT did catch.  Deleting one is an edit rather than a
#  fault, and paying for it with a number that must be updated in two
#  files has now cost more than it saved.
#
#  One consequence: an <img> shown as an EXAMPLE inside a fenced block
#  would read as a swallowed picture.  Write that one as &lt;img.
BEGIN{ fence=0; det=0; bad=0; imgs=0; raw=0 }
{
  line = $0
  #  the raw count comes first, because the fence lines themselves and
  #  everything inside them are skipped below
  probe = line
  while(match(probe, /<img src="/)){ raw++; probe = substr(probe, RSTART+RLENGTH) }
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
  #  reader.  A gap here means a fence has eaten one.
  if(imgs < raw){
    printf "  %d <img> tag(s) are in the file but only %d render - a fence has swallowed %d\n", raw, imgs, raw-imgs
    bad++
  }
  printf "READMERESULT %d %d\n", bad, imgs
}
