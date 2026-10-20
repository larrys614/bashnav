#  Drop the trailing "Question:" block from a captured lesson.
#
#  cmd=lesson prints the body, then a rule, then the question, then a
#  blank. The question is carried separately in lessons.js so the page
#  can ask before it tells -- left in the body too it appears twice,
#  once as prose and once in the question box. That is exactly how it
#  looked.
#
#  THE TEST IS ON THE LINE WITH ITS COLOUR STRIPPED. The capture runs in
#  day mode so that the author's emphasis survives, and in that mode the
#  line reads ESC[1;32mQuestion:ESC[40mESC[37m ... -- so an anchor on
#  "^  Question: " matches nothing at all, which is what it did.
#
#  One line is held back, so the rule that introduces the question goes
#  with the question rather than ending the body. The hold is tracked
#  with a FLAG, not by testing the held line against "": a blank line is
#  a real line here, it is the paragraph break, and testing for
#  emptiness silently dropped 84 of them.
BEGIN{ E = sprintf("%c", 27) }
{
  bare = $0
  gsub(E "\\[[0-9;]*m", "", bare)
  if(bare ~ /^  Question: /){ done=1; have=0; next }   # and drop the held rule
  if(done) next                                        # and the blank after it
  if(have) print held
  held = $0; have = 1
}
END{ if(have) print held }
