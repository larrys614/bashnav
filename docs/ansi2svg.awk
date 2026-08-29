#  ansi2svg -- turn a tool's real coloured output into an SVG picture.
#
#  GitHub will not render ANSI escapes in a code block and strips inline
#  styles from a README, but it does render an SVG image. So the art on
#  the front page can be the actual output of the actual program, in the
#  actual colours, rather than a plain-text approximation of it.
#
#  Reads ANSI on stdin, writes SVG on stdout.
#    -v title=...   accessible title for the image
#    -v pad=...     margin in pixels (default 14)
#
#  The palette is the site's, so the pictures belong to the same world as
#  the pages around them.
function hexof(c){
  if(c=="30") return "#0b1a22"
  if(c=="31") return "#e8695c"
  if(c=="32") return "#5cbf94"
  if(c=="33") return "#e3b862"
  if(c=="34") return "#6fa8d0"
  if(c=="35") return "#e2589a"
  if(c=="36") return "#7fd4e3"
  if(c=="37") return "#c9d6dc"
  if(c=="90") return "#72868f"
  if(c=="91") return "#e8695c"
  if(c=="92") return "#5cbf94"
  if(c=="93") return "#e3b862"
  if(c=="94") return "#8fc4e8"
  if(c=="95") return "#f07ab4"
  if(c=="96") return "#9fe4f0"
  if(c=="97") return "#ffffff"
  return ""
}
function xesc(s){ gsub(/&/,"\\&amp;",s); gsub(/</,"\\&lt;",s); gsub(/>/,"\\&gt;",s); return s }
#  Emit each run at an explicit x, computed from its column. Nothing then
#  depends on the renderer preserving runs of spaces - GitHub's SVG
#  sanitiser drops xml:space, which collapses every indent and shears the
#  art sideways. A character's position is arithmetic, so state it.
#  Emit each run as one or more whitespace-free chunks, each at its own
#  column. NO SPACE is ever written into the SVG: XML collapses runs of
#  whitespace in text content, and once it does, a per-character x list
#  no longer lines up with the characters it was built for - everything
#  after a gap slides left, which is how the meridian ended up sitting
#  against a line of position. A gap is expressed by arithmetic, never by
#  spaces.
function flush_run(   i,n,c,chunk,col0){
  if(RUN=="") { RCOL=CCOL; return }
  n=length(RUN)
  chunk=""; col0=0
  for(i=1;i<=n;i++){
    c=substr(RUN,i,1)
    if(c==" "){
      if(chunk!=""){ NR_++; RX[NR_]=RCOL+col0; RTX[NR_]=xesc(chunk); RC[NR_]=COL; RW[NR_]=chunk; chunk="" }
      continue
    }
    if(chunk=="") col0=i-1
    chunk=chunk c
  }
  if(chunk!=""){ NR_++; RX[NR_]=RCOL+col0; RTX[NR_]=xesc(chunk); RC[NR_]=COL; RW[NR_]=chunk }
  RUN=""; RCOL=CCOL
}
BEGIN{
  ESC=sprintf("%c",27)
  if(pad=="") pad=14
  nl=0; maxc=0
}
{
  s=$0; COL=""; RUN=""; CCOL=0; RCOL=0; NR_=0
  i=1; n=length(s)
  while(i<=n){
    c=substr(s,i,1)
    if(c==ESC){
      j=i+1
      if(substr(s,j,1)!="["){ i++; continue }
      j++
      p=""
      while(j<=n && substr(s,j,1) ~ /[0-9;]/){ p=p substr(s,j,1); j++ }
      fin=substr(s,j,1)
      if(fin=="m"){
        flush_run()
        if(p=="" || p=="0"){ COL=""; BOLD=0 }
        else {
          k=split(p,a,";")
          for(q=1;q<=k;q++){
            v=a[q]
            if(v=="0"){ COL=""; BOLD=0 }
            else if(v=="1"){ BOLD=1 }
            else if((v+0)>=30 && (v+0)<=37){
              COL = (BOLD) ? hexof(sprintf("%d",v+60)) : hexof(v)
            }
            else if((v+0)>=90 && (v+0)<=97) COL=hexof(v)
          }
          BOLD=0
        }
      }
      i=j+1
      continue
    }
    RUN=RUN c; CCOL++
    i++
  }
  flush_run()
  nl++
  LN[nl]=NR_
  for(q=1;q<=NR_;q++){ LX[nl,q]=RX[q]; LT[nl,q]=RTX[q]; LC[nl,q]=RC[q]; LR[nl,q]=RW[q] }
  if(CCOL>maxc) maxc=CCOL
}
END{
  #  Every CHARACTER gets its own x. SVG's text element takes a list of
  #  x coordinates, one per glyph, which is exactly what a terminal grid
  #  is. Positioning whole runs is not enough: the glyphs inside a run
  #  still advance by the FONT's width, and if the reader has no
  #  monospace font - or a different one - the line drifts and a vertical
  #  rule stops being vertical. With a coordinate per character nothing
  #  depends on the font's metrics at all.
  fw=8.0; fh=17; fs=13
  w = int(maxc*fw + 2*pad + 0.5)
  h = int(nl*fh + 2*pad + 0.5)
  printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">\n", w, h, w, h
  printf "<title>%s</title>\n", xesc(title)
  printf "<rect width=\"%d\" height=\"%d\" fill=\"#0b1a22\"/>\n", w, h
  printf "<g font-family=\"ui-monospace,SFMono-Regular,Menlo,Consolas,DejaVu Sans Mono,monospace\" font-size=\"%d\">\n", fs
  for(i=1;i<=nl;i++){
    for(q=1;q<=LN[i];q++){
      t = LT[i,q]
      #  the x list must have one entry per RENDERED character, so it is
      #  built from the unescaped run, not from the escaped markup
      raw = LR[i,q]
      xs=""
      for(c=0;c<length(raw);c++)
        xs = xs sprintf("%s%.1f", (c?" ":""), pad + (LX[i,q]+c)*fw)
      printf "<text x=\"%s\" y=\"%.1f\" fill=\"%s\">%s</text>\n",
        xs, pad + i*fh - 4, (LC[i,q]=="" ? "#c9d6dc" : LC[i,q]), t
    }
  }
  print "</g>\n</svg>"
}
