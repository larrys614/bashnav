#  The walkthrough's own sight, from W_setup() rather than retyped.
#
#  Step 6 draws the navigational triangle for this sight, and the browser
#  draws it with the sandbox's own code - which needs the latitude, the
#  declination and the LHA. Those are all in W_setup(), so they come from
#  there: the alternative is reading them back out of the step's prose,
#  which is a parser waiting to break, or typing them into the page, which
#  is the drift this whole generator exists to prevent.
BEGIN{
  W_setup()
  printf "window.CELNAV_WALK_CASE = { \"utc\": \"%s\", \"body\": \"%s\",\n", W_UTC, W_BODY
  printf "  \"lat\": %.10f, \"lon\": %.10f, \"dec\": %.10f, \"lha\": %.10f,\n", W_LAT, W_LON, W_DEC, W_LHA
  printf "  \"hs\": %.10f, \"ie\": %.4f, \"he\": %.4f, \"temp\": %.4f, \"press\": %.4f,\n", W_HS, W_IE, W_HE, W_T, W_P
  printf "  \"ho\": %.10f, \"hc\": %.10f, \"zn\": %.10f, \"intercept\": %.10f };\n", W_HO, W_HC, W_ZN, W_INT
}
