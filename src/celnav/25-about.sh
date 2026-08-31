about_why() {
  printf '%s\n' \
    '' \
    '  WHY THIS EXISTS' \
    '  ---------------------------------------------------------------' \
    '  Larry Sherman asked for it.' \
    '' \
    '  He served in the United States Navy from 1984 to 1990 as an' \
    '  FTG2/SS - a fire control technician, submarines - in USS Alaska' \
    '  (SSBN-732), USS Lafayette (SSBN-616), USS Gato (SSN-615) and USS' \
    '  Greenling (SSN-614).  Two ballistic missile boats and two fast' \
    '  attacks, which is two quite different trades: one hides and one' \
    '  goes looking.  He stood the manoeuvring watch on the fire control' \
    '  tracking party, managing contacts and avoiding collisions through' \
    '  places like the Strait of Gibraltar and the Race - the tide gate' \
    '  at the mouth of Long Island Sound, and the door you go out of' \
    '  from Groton.' \
    '' \
    '  Thirty-six years on he is sailing round the world in the Clipper' \
    '  Race, and he wanted a' \
    '  sight reduction that would work on an iPad in the middle of an' \
    '  ocean: no signal, no subscription, no account to log in to, no' \
    '  almanac to download first.' \
    '' \
    '  And he wanted it to DRAW the solution.  A fix that arrives as' \
    '  three numbers teaches you nothing about whether to believe it.' \
    '  A fix that arrives as three lines on a plot, with the cut' \
    '  between them and an error ellipse around the result, tells you' \
    '  at a glance whether you have a fix or an opinion.  That is why' \
    '  the intercept plot is the point of this program rather than a' \
    '  decoration on it.' \
    '' \
    '  Everything else follows from "no internet".  The almanac is not' \
    '  fetched; it is computed, from orbital theory, inside the file' \
    '  you are running.  There is no table to expire and no server to' \
    '  go away.  It is text, you can read every line of it, and' \
    '  "celnav doctor" will check it against an independent reference' \
    '  in front of you.' \
    ''
}
about_sources() {
  printf '%s\n' \
    '' \
    '  SOURCES' \
    '  ---------------------------------------------------------------' \
    '  ASTRONOMY' \
    '    Jean Meeus, "Astronomical Algorithms", 2nd edition.  The solar' \
    '    theory is chapter 25 and the lunar main problem chapter 47,' \
    '    with nutation and sidereal time from the same book.' \
    '' \
    '    E. M. Standish, Keplerian elements for approximate positions' \
    '    of the major planets (Jet Propulsion Laboratory).  The raw' \
    '    elements lose several arcminutes on Saturn to the great' \
    '    inequality with Jupiter, so a periodic correction series was' \
    '    fitted here against an independent ephemeris; Saturn is now' \
    '    the most accurate planet in the set.' \
    '' \
    '    Precession and annual aberration by the standard series.' \
    '    Star positions from the Hipparcos and Yale catalogues, with' \
    '    proper motion applied for the date.  Delta T from the' \
    '    Espenak-Meeus polynomials, with the observed plateau after' \
    '    2005.' \
    '' \
    '  METHOD' \
    '    The intercept method - Marcq St Hilaire - as in the Nautical' \
    '    Almanac'\''s sight reduction procedure.  Dip, refraction,' \
    '    semi-diameter, parallax and index error applied in the usual' \
    '    order.  The fix is an iterated least-squares solution of every' \
    '    line of position at once, not a two-body cut, and the error' \
    '    ellipse comes out of the normal matrix.' \
    '' \
    '  CHECKED BY' \
    '    An independent reference ephemeris of JPL grade, over the' \
    '    whole period the program covers, embedded so that the check' \
    '    works with no network.  "celnav doctor" runs it.' \
    ''
}
about_tested() {
  printf '%s\n' \
    '' \
    '  WHAT IS TESTED, AND WHAT IS NOT' \
    '  ---------------------------------------------------------------' \
    '  THE NUMBERS.  "celnav doctor", which you can run yourself.' \
    '' \
    '    The almanac is checked, body by body and date by date, against' \
    '    an independent reference ephemeris of JPL grade, embedded so' \
    '    that the check works with no network.  It prints the worst' \
    '    error it found in arcminutes.  If that number is not small,' \
    '    nothing downstream of it means anything.' \
    '' \
    '  THE WHOLE CHAIN.  tests/run-tests.sh, under four awks and two' \
    '  shells.' \
    '' \
    '    Three star sights taken from a known position are reduced,' \
    '    and the fix has to come back to the position they were taken' \
    '    from, to a tenth of a minute.  That exercises everything at' \
    '    once: the almanac, dip, refraction, semi-diameter, parallax,' \
    '    index error, the navigational triangle, the least-squares' \
    '    solution and the run.  Every drill must also mark its own' \
    '    correct answer as correct.' \
    '' \
    '  THE GOLDEN FILES.  tests/golden.sh' \
    '' \
    '    The almanac for five dates spread across twenty years, the' \
    '    star list, and four worked reductions - a clean one, the same' \
    '    one on the run, one with a five-mile blunder in it, and a' \
    '    weak cut - captured as text and committed.  Any change to any' \
    '    number turns up as a diff that has to be read and accepted on' \
    '    purpose.' \
    '' \
    '  NOW THE HONEST PART.' \
    '' \
    '  All of that checks the ARITHMETIC.  None of it checks the' \
    '  SEAMANSHIP.' \
    '' \
    '  A test can confirm that the program computes the sun'\''s GHA to' \
    '  within a tenth of a minute.  It cannot tell you whether the' \
    '  advice in the lessons is good practice, whether the order the' \
    '  corrections are explained in is the order you should learn' \
    '  them, or whether the walkthrough matches how a sight is' \
    '  actually taken on a wet deck at dawn.' \
    '' \
    '  Nor does it check the program against a printed Nautical' \
    '  Almanac, which is a different authority from the one it was' \
    '  validated against.  If you have one, that comparison is worth' \
    '  more than anything else you could send.' \
    ''
}
about_needs() {
  printf '%s\n' \
    '  AND HERE IS WHERE IT IS WORTH MOST.' \
    '' \
    '  1  A FIX THAT DISAGREES WITH YOURS.  If you work a sight by' \
    '     hand or with tables and this program gives you something' \
    '     else, that is the most valuable report there is.  Send the' \
    '     sights, the time, the height of eye, the index error and' \
    '     what you got.  One of us is wrong and it is worth knowing' \
    '     which.' \
    '' \
    '  2  THE ALMANAC AGAINST A PRINTED ONE.  GHA, declination, SD and' \
    '     HP for any body and time, checked against the Nautical' \
    '     Almanac.  It has been validated against a computed reference,' \
    '     never against the book.' \
    '' \
    '  3  THE TEACHING.  Whether the lessons and the walkthrough match' \
    '     how it is really done - and whether anything in them would' \
    '     build a bad habit.  Corrections to the teaching matter as' \
    '     much as corrections to the code.' \
    '' \
    '  4  THE AWKWARD CASES.  A lower limb near the horizon, a very' \
    '     high altitude, extreme temperature or pressure, a sight' \
    '     close to the pole, a moon sight with a large parallax.  The' \
    '     ordinary cases are well covered.  The edges are where the' \
    '     corrections are applied in an order somebody has to check.' \
    ''
}
