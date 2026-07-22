local _ = require("gettext")
return {
    name = "rebind",
    fullname = _("Rebind"),
    description = _([[Update an EPUB's embedded metadata (title, author, series) from Hardcover, rewriting the file in place. Requires the Hardcover plugin (hardcoverapp.koplugin) to be installed and configured.]]),
}
