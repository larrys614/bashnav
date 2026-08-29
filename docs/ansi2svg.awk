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
function flush_run(   t){
  if(RUN=="") { RCOL=CCOL; return }
  #  a run of pure spaces carries no ink: skip it, the next run's x
  #  already accounts for the gap
  if(RUN ~ /^ +$/){ RUN=""; RCOL=CCOL; return }
  #  and trim the spaces off either end, moving the start column to
  #  match - a leading space that a renderer collapses would shear the
  #  run sideways, and the position is arithmetic anyway
  while(substr(RUN,1,1)==" "){ RUN=substr(RUN,2); RCOL++ }
  while(substr(RUN,length(RUN),1)==" ") RUN=substr(RUN,1,length(RUN)-1)
  t = xesc(RUN)
  NR_++
  RX[NR_]=RCOL; RTX[NR_]=t; RC[NR_]=COL
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
  for(q=1;q<=NR_;q++){ LX[nl,q]=RX[q]; LT[nl,q]=RTX[q]; LC[nl,q]=RC[q] }
  if(CCOL>maxc) maxc=CCOL
}
END{
  fw=8.4; fh=17; fs=14
  w = int(maxc*fw + 2*pad + 0.5)
  h = int(nl*fh + 2*pad + 0.5)
  printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">\n", w, h, w, h
  printf "<title>%s</title>\n", xesc(title)
  printf "<rect width=\"%d\" height=\"%d\" fill=\"#0b1a22\"/>\n", w, h
  printf "<g font-family=\"ui-monospace,SFMono-Regular,Menlo,Consolas,DejaVu Sans Mono,monospace\" font-size=\"%d\">\n", fs
  for(i=1;i<=nl;i++){
    for(q=1;q<=LN[i];q++){
      printf "<text x=\"%.1f\" y=\"%.1f\" fill=\"%s\">%s</text>\n",
        pad + LX[i,q]*fw, pad + i*fh - 4,
        (LC[i,q]=="" ? "#c9d6dc" : LC[i,q]), LT[i,q]
    }
  }
  print "</g>\n</svg>"
}
