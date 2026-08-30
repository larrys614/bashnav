#!/bin/sh
#  The launcher exists for the iPad, where five home-screen icons need
#  five Shortcuts and one icon needs none.  It must find the tools
#  wherever they actually are, and it must say so plainly when it
#  cannot - a launcher that fails silently is worse than no launcher.
set -e
cd "$(dirname "$0")/.."
SH=${1:-sh}
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
bad=0; say(){ echo "  FAIL $1"; bad=1; }

#  1. every tool in bin/ must be offered by the menu
menu=$(printf 'q\n' | $SH ./bin/bashnav)
for t in $(ls bin/ | grep -v '^bashnav$'); do
  case "$menu" in *"$t"*) ;; *) say "the menu does not offer $t" ;; esac
done

#  2. and found, when run from the repo
w=$($SH ./bin/bashnav where)
for t in $(ls bin/ | grep -v '^bashnav$'); do
  case "$w" in *"$t"*bin/"$t"*) ;;
    *) case "$w" in *"$t "*"not found"*) say "$t was not found next to the launcher" ;; esac ;;
  esac
done

#  3. it finds a tool in ~/Documents, which is the only place iOS lets
#     an app write and therefore where an iPad user will have put them
mkdir -p "$d/home/Documents"
printf '#!/bin/sh\necho I AM TIDES\n' > "$d/home/Documents/tides"
chmod +x "$d/home/Documents/tides"
cp bin/bashnav "$d/"
o=$(cd "$d" && HOME="$d/home" PATH=/usr/bin:/bin $SH ./bashnav tides)
case "$o" in "I AM TIDES") ;; *) say "a tool in ~/Documents was not found: [$o]" ;; esac

#  4. asking for something that is not there says so, and does not
#     pretend to have run it
if o=$(cd "$d" && HOME="$d/home" PATH=/usr/bin:/bin $SH ./bashnav celnav 2>&1); then
  say "a missing tool exited 0"
else
  case "$o" in *"cannot find"*) ;; *) say "a missing tool did not say so: [$o]" ;; esac
fi

#  5. arguments pass straight through
printf '#!/bin/sh\necho "GOT [$*]"\n' > "$d/home/Documents/weather"
chmod +x "$d/home/Documents/weather"
o=$(cd "$d" && HOME="$d/home" PATH=/usr/bin:/bin $SH ./bashnav weather learn tide)
case "$o" in "GOT [learn tide]") ;; *) say "arguments were not passed through: [$o]" ;; esac

#  6. the menu pasted into the README is the menu the program prints.
#     Every plate in this README has drifted at least once; a hand-copied
#     block with a version number in it will drift the day the version
#     changes.  The block is the one inside the "## bashnav" section.
awk '
  /^## bashnav$/ { sec=1; next }
  sec && /^## / { sec=0 }
  sec && /^```/ { inb = !inb; next }
  sec && inb    { print }
' README.md > "$d/readme-menu"
#  the last line is "  > " with no newline after it, so add one
{ printf 'q\n' | $SH ./bin/bashnav; echo; } |
  sed -e '1{/^$/d;}' -e 's/[[:space:]]*$//' > "$d/real-menu"
sed -e 's/[[:space:]]*$//' "$d/readme-menu" > "$d/rm2"
if [ ! -s "$d/readme-menu" ]; then
  say "no menu block found in the README's bashnav section"
elif ! diff -u "$d/rm2" "$d/real-menu" > "$d/dd" 2>&1; then
  say "the README's menu has drifted from the program"
  sed -n '3,14p' "$d/dd" | sed 's/^/       /'
fi

[ "$bad" = 0 ] && echo "LAUNCHER OK"
exit $bad
