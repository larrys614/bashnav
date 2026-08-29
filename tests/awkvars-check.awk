#  Assigning to one of awk's built-in variables from ordinary code is a
#  silent, action-at-a-distance bug: a global called RS is the record
#  separator, so setting it to a number makes the next getline read an
#  entire file as one record with no error anywhere. This walks the
#  sources looking for such an assignment.
BEGIN{
  #  POSIX awk's built-ins, plus the gawk ones - RT bit me while writing
  #  the SVG generator, which is exactly what this check exists for.
  n=split("FS OFS ORS RS NR NF FNR FILENAME SUBSEP RSTART RLENGTH CONVFMT " \
          "OFMT ARGC ARGV ENVIRON RT FIELDWIDTHS FPAT IGNORECASE BINMODE " \
          "LINT TEXTDOMAIN PROCINFO ERRNO",B," ")
  for(i=1;i<=n;i++) BUILT[B[i]]=1
  bad=0
}
#  skip comments and the inside of quoted strings, crudely but safely:
#  a false positive here costs a rename, a false negative costs a day
{
  line=$0
  sub(/#.*/,"",line)
  gsub(/"[^"]*"/,"",line)
  for(v in BUILT){
    if(line ~ ("(^|[^A-Za-z0-9_])" v "[ \t]*=[^=]")){
      #  FS and friends are legitimately set in a BEGIN block on purpose;
      #  flag everything and let the caller allow the deliberate ones
      printf "%s:%d: assigns to built-in %s\n", FILENAME, FNR, v
      bad++
    }
  }
}
END{ printf "BAD %d\n", bad }
