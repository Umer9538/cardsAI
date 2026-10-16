Deliberately empty.

goldie-all is a VIEW-ONLY config: it exists so one studio can show the
iPhone, Android and iPad strips together. It has no flows, so `goldie
capture` run from goldie-all fails immediately with a missing-flow error
instead of replaying one device's coordinates against another's screen.

Capture from ../goldie (iPhone + Android) or ../goldie-ipad (iPad).
