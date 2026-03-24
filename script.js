const form = document.getElementById("handle-form");
const input = document.getElementById("handle-input");
const report = document.getElementById("report");

const vibeProfiles = [
  {
    name: "Cinematic Oversharer",
    description:
      "Your grid suggests a brave commitment to mood, lighting, and posting like the audience is emotionally invested in chapter three."
  },
  {
    name: "Low-Key Attention Wizard",
    description:
      "Acts chill, posts chill, somehow still makes everyone ask where that jacket, cafe, skyline, and entire personality came from."
  },
  {
    name: "Soft-Launch Strategist",
    description:
      "Never confirms anything directly. Prefers a sleeve, a reflection, or two coffees on the table and lets the comments perform the detective work."
  },
  {
    name: "Chaotic Taste Curator",
    description:
      "The account feels like a thrift store, a runway, and a minor emotional event were compressed into one algorithmically potent page."
  },
  {
    name: "Hyperlocal Legend",
    description:
      "Your stories imply you know three secret bakeries, one rooftop nobody else can access, and exactly when golden hour becomes smug."
  },
  {
    name: "Meme-Adjacent Heartbreaker",
    description:
      "The vibe says funny first, mysterious second, emotionally disruptive third. A dangerous sequence."
  }
];

const noteTemplates = [
  "Owns at least one post where the caption did 80% of the flirting.",
  "Understands the power of pretending a photo dump was spontaneous.",
  "Likely to delete a good picture because the first upload felt 'too available.'",
  "Treats close friends stories like a premium streaming platform.",
  "Knows the exact face angle that says 'I just happened to look incredible.'",
  "Would absolutely say 'this old thing?' about a very curated outfit.",
  "Posts one blurry photo on purpose to prove they are above perfection."
];

const forecastTemplates = [
  "The algorithm will reward one unexpectedly casual post and ignore the masterpiece you spent 45 minutes selecting.",
  "A stranger from another city will like three old posts tonight and then vanish like folklore.",
  "Your next carousel has strong 'save this for later' energy, even if nobody can explain why.",
  "An unnervingly specific ad is preparing to acknowledge your full personality within 48 hours.",
  "A single story sticker could temporarily alter your reputation in at least two group chats.",
  "Your account is one whimsical location tag away from becoming somebody else's Roman Empire."
];

const captionTemplates = [
  "Caption recommendation: mildly detached, weirdly poetic, and just specific enough to start theories.",
  "Caption recommendation: act like you almost didn't post it, even though the composition took planning and at least one retake.",
  "Caption recommendation: one lowercase sentence, one stray emoji, and the confidence of someone who knows the comments will do the rest.",
  "Caption recommendation: something that sounds like a private joke with the moon.",
  "Caption recommendation: give them six words, no explanation, and one suspiciously elegant comma."
];

function sanitizeHandle(value) {
  return value.replace(/[^a-zA-Z0-9._]/g, "").replace(/^@+/, "").slice(0, 30);
}

function hashHandle(handle) {
  let hash = 0;
  for (let i = 0; i < handle.length; i += 1) {
    hash = (hash * 31 + handle.charCodeAt(i)) >>> 0;
  }
  return hash;
}

function pickMany(source, hash, count) {
  const pool = [...source];
  const picks = [];
  let seed = hash || 1;

  while (picks.length < count && pool.length > 0) {
    const index = seed % pool.length;
    picks.push(pool.splice(index, 1)[0]);
    seed = ((seed * 1664525) + 1013904223) >>> 0;
  }

  return picks;
}

function percentFromHash(hash, min, max, shift) {
  const range = max - min + 1;
  return `${min + ((hash >>> shift) % range)}%`;
}

function buildSummary(handle, hash, vibe) {
  const lengthComment =
    handle.length <= 6
      ? "Short handle, huge confidence."
      : handle.includes(".")
        ? "The punctuation implies either elegance or logistics."
        : "A clean uninterrupted handle usually means the brand committee is one person and very powerful.";

  const underscoreComment = handle.includes("_")
    ? "The underscore adds a tasteful amount of dramatic spacing."
    : "No underscores. Fearless.";

  return `${lengthComment} ${underscoreComment} Overall assessment: ${vibe.name.toLowerCase()} behavior with a suspicious talent for making ordinary moments look headline-worthy.`;
}

function renderReport(handle) {
  const hash = hashHandle(handle);
  const vibe = vibeProfiles[hash % vibeProfiles.length];
  const notes = pickMany(noteTemplates, hash, 3);
  const forecast = pickMany(forecastTemplates, hash >>> 2, 3);
  const caption = captionTemplates[(hash >>> 5) % captionTemplates.length];

  document.getElementById("report-title").textContent = `@${handle} is under review`;
  document.getElementById("report-summary").textContent = buildSummary(handle, hash, vibe);
  document.getElementById("vibe-name").textContent = vibe.name;
  document.getElementById("vibe-description").textContent = vibe.description;
  document.getElementById("main-character").textContent = percentFromHash(hash, 64, 99, 0);
  document.getElementById("dm-chaos").textContent = percentFromHash(hash, 12, 91, 7);
  document.getElementById("soft-launch").textContent = percentFromHash(hash, 8, 97, 13);
  document.getElementById("caption-energy").textContent = caption;

  const behaviorList = document.getElementById("behavior-list");
  const forecastList = document.getElementById("forecast-list");
  behaviorList.innerHTML = "";
  forecastList.innerHTML = "";

  notes.forEach((item) => {
    const li = document.createElement("li");
    li.textContent = item;
    behaviorList.appendChild(li);
  });

  forecast.forEach((item) => {
    const li = document.createElement("li");
    li.textContent = item;
    forecastList.appendChild(li);
  });

  report.classList.remove("hidden");
  requestAnimationFrame(() => report.classList.add("visible"));
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const handle = sanitizeHandle(input.value.trim());

  if (!handle) {
    input.focus();
    input.placeholder = "please enter a real-ish handle";
    return;
  }

  input.value = handle;
  renderReport(handle);
});

renderReport("chaoticcappuccino");
