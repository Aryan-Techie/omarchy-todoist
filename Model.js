// Pure data helpers for the Todoist panel: response shaping, sorting, and
// error-message translation. No QML/Qt types here so this stays testable on
// its own — the panel owns everything stateful (curl processes, settings
// file, UI).

function safeTrim(value) {
  return String(value === undefined || value === null ? "" : value).trim()
}

// Todoist filter query (e.g. "today | overdue"). Falls back to the default
// due/overdue view whenever the user clears the field.
function sanitizeFilter(filter) {
  var trimmed = safeTrim(filter)
  return trimmed === "" ? "today | overdue" : trimmed
}

function pad2(n) {
  return n < 10 ? "0" + n : String(n)
}

// due.date is either a plain "YYYY-MM-DD" or a full ISO timestamp depending
// on whether the task has a time component. The first 10 characters are the
// date either way.
function isoDatePrefix(dateStr) {
  var s = String(dateStr || "")
  return s.length >= 10 ? s.substring(0, 10) : s
}

function todayIsoDate() {
  var now = new Date()
  return now.getFullYear() + "-" + pad2(now.getMonth() + 1) + "-" + pad2(now.getDate())
}

// Prefers Todoist's own human phrasing ("tomorrow at 10:00") and only falls
// back to the raw date when a task has a due date but no string form.
function taskDueLabel(task) {
  if (!task || !task.due) return ""
  return task.due.string || isoDatePrefix(task.due.date)
}

function taskIsOverdue(task) {
  if (!task || !task.due || !task.due.date) return false
  return isoDatePrefix(task.due.date) < todayIsoDate()
}

// Overdue/due-soonest first, undated tasks last; priority breaks ties within
// the same date, then content for a stable order.
function sortedTasks(tasks) {
  var list = (tasks || []).slice()
  list.sort(function(a, b) {
    var aDue = a && a.due && a.due.date ? isoDatePrefix(a.due.date) : ""
    var bDue = b && b.due && b.due.date ? isoDatePrefix(b.due.date) : ""
    if (aDue !== bDue) {
      if (aDue === "") return 1
      if (bDue === "") return -1
      return aDue < bDue ? -1 : 1
    }

    var aPriority = a && typeof a.priority === "number" ? a.priority : 1
    var bPriority = b && typeof b.priority === "number" ? b.priority : 1
    if (aPriority !== bPriority) return bPriority - aPriority

    var aContent = (a && a.content) || ""
    var bContent = (b && b.content) || ""
    return aContent < bContent ? -1 : (aContent > bContent ? 1 : 0)
  })
  return list
}

// curl exits non-zero with an empty stdout body on HTTP errors (-f), so the
// only signal available for a friendly message is the exit code and
// whatever curl printed to stderr.
function errorMessageForExit(exitCode, stderrText) {
  var text = String(stderrText || "")
  if (text.indexOf("401") !== -1 || text.indexOf("403") !== -1)
    return "Todoist rejected the API token — check it in Settings."
  if (text.indexOf("Could not resolve host") !== -1 || text.indexOf("Couldn't connect") !== -1
    || text.indexOf("Failed to connect") !== -1 || text.indexOf("Network is unreachable") !== -1)
    return "Couldn't reach Todoist — check your connection."
  if (exitCode === 28) return "Todoist took too long to respond."
  var firstLine = text.split("\n")[0]
  return "Something went wrong talking to Todoist" + (firstLine !== "" ? (": " + firstLine) : ".")
}
