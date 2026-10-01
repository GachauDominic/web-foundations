let notes = [
  { id: 1, text: "Buy milk and bread", category: "personal" },
  { id: 2, text: "Finish the Day 3 assignment", category: "study" },
  { id: 3, text: "Email the project report to Grace", category: "work" },
  { id: 4, text: "Revise JavaScript arrays", category: "study" },
  { id: 5, text: "Call mum", category: "personal" },
];

// 1. Search notes
function searchNotes(word) {
  return notes.filter((note) =>
    note.text.toLowerCase().includes(word.toLowerCase()),
  );
}

// Normal case
console.log(searchNotes("javascript"));
// Expected: [{ id: 4, text: "Revise JavaScript arrays", category: "study" }]

// Edge case: no matching notes
console.log(searchNotes("football"));
// Expected: []

// 2. Find the longest note
function longestNote() {
  if (notes.length === 0) {
    return null;
  }

  let longest = notes[0];

  for (let i = 1; i < notes.length; i++) {
    if (notes[i].text.length > longest.text.length) {
      longest = notes[i];
    }
  }

  return longest;
}

// Normal case
console.log(longestNote());
// Expected: { id: 3, text: "Email the project report to Grace", category: "work" }

// Edge case: empty notes array
let originalNotes = notes;
notes = [];
console.log(longestNote());
// Expected: null
notes = originalNotes;

// 3. Count notes by category
function countByCategory() {
  let counts = {};

  for (let note of notes) {
    if (counts[note.category]) {
      counts[note.category]++;
    } else {
      counts[note.category] = 1;
    }
  }

  return counts;
}

// Normal case
console.log(countByCategory());
// Expected: { personal: 2, study: 2, work: 1 }

// Edge case: empty notes array
notes = [];
console.log(countByCategory());
// Expected: {}
notes = originalNotes;

// 4. Get summary
function getSummary() {
  const counts = countByCategory();
  const total = notes.length;

  const noteWord = total === 1 ? "note" : "notes";

  return `${total} ${noteWord}: ${counts.personal || 0} personal, ${
    counts.work || 0
  } work, ${counts.study || 0} study.`;
}

// Normal case
console.log(getSummary());
// Expected: "5 notes: 2 personal, 1 work, 2 study."

// Edge case: one note
notes = [{ id: 1, text: "Buy milk and bread", category: "personal" }];

console.log(getSummary());
// Expected: "1 note: 1 personal, 0 work, 0 study."

notes = originalNotes;

// 5. Check for duplicates
function isDuplicate(text) {
  return notes.some(
    (note) => note.text.trim().toLowerCase() === text.trim().toLowerCase(),
  );
}

// Normal case
console.log(isDuplicate("Call mum"));
// Expected: true

// Edge case: different text
console.log(isDuplicate("Call dad"));
// Expected: false

// 6. Add a note
function addNote(text, category) {
  const validCategories = ["personal", "work", "study"];

  if (text.trim().length < 1 || text.length > 200) {
    console.log("Note must be between 1 and 200 characters.");
    return false;
  }

  if (isDuplicate(text)) {
    console.log("Note already exists.");
    return false;
  }

  if (!validCategories.includes(category)) {
    console.log("Invalid category.");
    return false;
  }

  const newId =
    notes.length > 0 ? Math.max(...notes.map((note) => note.id)) + 1 : 1;

  notes.push({
    id: newId,
    text: text.trim(),
    category: category,
  });

  return true;
}

// Normal case
console.log(addNote("Study JavaScript functions", "study"));
// Expected: true

// Edge case: duplicate note
console.log(addNote("  study javascript functions  ", "study"));
// Expected: false
