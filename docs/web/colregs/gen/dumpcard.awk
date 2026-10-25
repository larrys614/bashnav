#  The contacts reference card, one reporting style at a time, as a
#  JavaScript string.
#
#  THIS USED TO BE AN INLINE PROGRAM in make-colregs-web.sh, and it had to
#  become a file: the escaping moved to the shared docs/web/gen/jsonesc.awk,
#  which arrives as -f, and `-f file` and an inline program DO NOT MIX.
#  awk takes the inline text as the name of a DATA file, runs only what -f
#  gave it, and says nothing - so the card generated as five empty strings
#  and the only sign was the committed file changing. See docs/HACKING.md.
#
#  The terminal's furniture comes off: the rule hr() draws under the
#  heading and above the foot, and the heading itself, which the screen
#  already shows as its title. Same two chores dumpclesson.awk does for a
#  lesson, and for the same reason - the first version of that one carried
#  a row of dashes into the page.
/^ *-+ *$/ { next }
/CONTACTS -- the card/ { next }
{
  $0 = js_dq_raw($0)
  sub(/^  /, "")
  sub(/[ \t]+$/, "")
  L[++n] = $0
}
#  blank lines top and bottom go, the ones in the middle stay: they are
#  the card's own spacing.
END{
  s = 1; while(s <= n && L[s] == "") s++
  e = n; while(e >= 1 && L[e] == "") e--
  for(i = s; i <= e; i++) printf "%s\\n", L[i]
}
