#  The SVG pictures must be an exact character grid.
#
#  This broke three times: xml:space stripped by GitHub's sanitiser, then
#  glyphs inside a run advancing by the font's width, then XML collapsing
#  runs of spaces so a per-character x list no longer matched its text.
#  All three had the same signature - the meridian on the intercept plot
#  stopped being vertical - and none was visible without rendering the
#  thing and looking at it. So: check the arithmetic directly.
#
#  Reads an SVG on stdin. -v pad, -v fw must match the generator.
BEGIN{ bad=0; n=0 }
/<text /{
  n++
  line=$0
  #  no text element may contain a space: a space in the content is what
  #  XML collapses, and the collapse is what shears the grid
  if(match(line, />[^<]*</)){
    body=substr(line, RSTART+1, RLENGTH-2)
    if(body ~ / /){ printf "text content contains a space: %s\n", substr(body,1,40); bad++ }
  }
  #  every x must sit exactly on the grid
  if(match(line, /x="[^"]*"/)){
    xs=substr(line, RSTART+3, RLENGTH-4)
    k=split(xs, A, " ")
    for(i=1;i<=k;i++){
      col=(A[i]-pad)/fw
      if(col != int(col)){ printf "x=%s is not on the grid (col %.3f)\n", A[i], col; bad++ }
    }
    #  and the coordinates must be consecutive columns
    for(i=2;i<=k;i++){
      if(A[i]-A[i-1] != fw){ printf "x list is not consecutive: %s then %s\n", A[i-1], A[i]; bad++ }
    }
  }
}
END{ printf "TEXTS %d BAD %d\n", n, bad }
