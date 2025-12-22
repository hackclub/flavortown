const audioBaseUrl =
  "https://raw.githubusercontent.com/maxwofford/shopkeepers/main/audio/";

const yap_sounds = {
  a: new Howl({ src: audioBaseUrl + "a.wav" }),
  b: new Howl({ src: audioBaseUrl + "b.wav" }),
  c: new Howl({ src: audioBaseUrl + "c.wav" }),
  d: new Howl({ src: audioBaseUrl + "d.wav" }),
  e: new Howl({ src: audioBaseUrl + "e.wav" }),
  f: new Howl({ src: audioBaseUrl + "f.wav" }),
  g: new Howl({ src: audioBaseUrl + "g.wav" }),
  h: new Howl({ src: audioBaseUrl + "h.wav" }),
  i: new Howl({ src: audioBaseUrl + "i.wav" }),
  j: new Howl({ src: audioBaseUrl + "j.wav" }),
  k: new Howl({ src: audioBaseUrl + "k.wav" }),
  l: new Howl({ src: audioBaseUrl + "l.wav" }),
  m: new Howl({ src: audioBaseUrl + "m.wav" }),
  n: new Howl({ src: audioBaseUrl + "n.wav" }),
  o: new Howl({ src: audioBaseUrl + "o.wav" }),
  p: new Howl({ src: audioBaseUrl + "p.wav" }),
  q: new Howl({ src: audioBaseUrl + "q.wav" }),
  r: new Howl({ src: audioBaseUrl + "r.wav" }),
  s: new Howl({ src: audioBaseUrl + "s.wav" }),
  t: new Howl({ src: audioBaseUrl + "t.wav" }),
  u: new Howl({ src: audioBaseUrl + "u.wav" }),
  v: new Howl({ src: audioBaseUrl + "v.wav" }),
  w: new Howl({ src: audioBaseUrl + "w.wav" }),
  x: new Howl({ src: audioBaseUrl + "x.wav" }),
  y: new Howl({ src: audioBaseUrl + "y.wav" }),
  z: new Howl({ src: audioBaseUrl + "z.wav" }),
  th: new Howl({ src: audioBaseUrl + "th.wav" }),
  sh: new Howl({ src: audioBaseUrl + "sh.wav" }),
  _: new Howl({ src: audioBaseUrl + "space.wav" }),
};

function yap(
  text,
  {
    letterCallback = () => {},
    endCallback = () => {},
    baseRate = 3.2,
    rateVariance = 1,
  } = {},
) {
  let cancelled = false;

  const queue = [];
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    const lower = char?.toLowerCase();
    const prevChar = text[i - 1];
    const prevLower = prevChar?.toLowerCase();
    const nextChar = text[i + 1];
    const nextLower = nextChar?.toLowerCase();

    if (lower === "s" && nextLower === "h") {
      queue.push({ letter: char, sound: yap_sounds.sh });
    } else if (lower === "t" && nextLower === "h") {
      queue.push({ letter: char, sound: yap_sounds.th });
    } else if (lower === "h" && (prevLower === "s" || prevLower === "t")) {
      queue.push({ letter: char, sound: yap_sounds._ });
    } else if (",?. ".includes(char)) {
      queue.push({ letter: char, sound: yap_sounds._ });
    } else if (lower !== prevLower && lower.match(/[a-z.]/)) {
      queue.push({ letter: char, sound: yap_sounds[lower] });
    } else {
      queue.push({ letter: char, sound: yap_sounds._ });
    }
  }

  function playNext() {
    if (cancelled) return;
    if (queue.length === 0) {
      endCallback();
      return;
    }

    const { sound, letter } = queue.shift();
    sound.rate(Math.random() * rateVariance + baseRate);
    sound.volume(1);
    sound.once("end", playNext);
    sound.play();
    sound.once("play", () => {
      if (!cancelled) {
        letterCallback({ sound, letter, length: queue.length });
      }
    });
  }

  playNext();

  return function cancel() {
    cancelled = true;
    Howler.stop();
  };
}
