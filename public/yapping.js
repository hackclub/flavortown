const audioBaseUrl = 'https://raw.githubusercontent.com/maxwofford/shopkeepers/main/audio/';

const yap_sounds = {
    // these sounds and most of the yapping code are adapted from https://github.com/equalo-official/animalese-generator
    a: new Howl({ src: audioBaseUrl + 'a.wav' }),
    b: new Howl({ src: audioBaseUrl + 'b.wav' }),
    c: new Howl({ src: audioBaseUrl + 'c.wav' }),
    d: new Howl({ src: audioBaseUrl + 'd.wav' }),
    e: new Howl({ src: audioBaseUrl + 'e.wav' }),
    f: new Howl({ src: audioBaseUrl + 'f.wav' }),
    g: new Howl({ src: audioBaseUrl + 'g.wav' }),
    h: new Howl({ src: audioBaseUrl + 'h.wav' }),
    i: new Howl({ src: audioBaseUrl + 'i.wav' }),
    j: new Howl({ src: audioBaseUrl + 'j.wav' }),
    k: new Howl({ src: audioBaseUrl + 'k.wav' }),
    l: new Howl({ src: audioBaseUrl + 'l.wav' }),
    m: new Howl({ src: audioBaseUrl + 'm.wav' }),
    n: new Howl({ src: audioBaseUrl + 'n.wav' }),
    o: new Howl({ src: audioBaseUrl + 'o.wav' }),
    p: new Howl({ src: audioBaseUrl + 'p.wav' }),
    q: new Howl({ src: audioBaseUrl + 'q.wav' }),
    r: new Howl({ src: audioBaseUrl + 'r.wav' }),
    s: new Howl({ src: audioBaseUrl + 's.wav' }),
    t: new Howl({ src: audioBaseUrl + 't.wav' }),
    u: new Howl({ src: audioBaseUrl + 'u.wav' }),
    v: new Howl({ src: audioBaseUrl + 'v.wav' }),
    w: new Howl({ src: audioBaseUrl + 'w.wav' }),
    x: new Howl({ src: audioBaseUrl + 'x.wav' }),
    y: new Howl({ src: audioBaseUrl + 'y.wav' }),
    z: new Howl({ src: audioBaseUrl + 'z.wav' }),
    th: new Howl({ src: audioBaseUrl + 'th.wav' }),
    sh: new Howl({ src: audioBaseUrl + 'sh.wav' }),
    _: new Howl({ src: audioBaseUrl + 'space.wav' })
  }

async function yap(text, {
  letterCallback = () => {},
  endCallback = () => {},
  baseRate = 3.2,
  rateVariance = 1,
} = {}) {

  const yap_queue = [];
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    const lowerChar = char?.toLowerCase()
    const prevChar = text[i - 1]
    const prevLowerChar = prevChar?.toLowerCase()
    const nextChar = text[i + 1]
    const nextLowerChar = nextChar?.toLowerCase()

    if (lowerChar === 's' && nextLowerChar === 'h') { // test for 'sh' sound
      yap_queue.push({letter: char, sound: yap_sounds['sh']});
      continue;
    } else if (lowerChar === 't' && nextLowerChar === 'h') { // test for 'th' sound
      yap_queue.push({letter: char, sound: yap_sounds['th']});
      continue;
    } else if (lowerChar === 'h' && (prevLowerChar === 's' || prevLowerChar === 't')) { // test if previous letter was 's' or 't' and current letter is 'h'
      yap_queue.push({letter: char, sound: yap_sounds['_']});
      continue;
    } else if (',?. '.includes(char)) {
      yap_queue.push({letter: char, sound: yap_sounds['_']});
      continue;
    } else if (lowerChar === prevLowerChar) { // skip repeat letters
      yap_queue.push({letter: char, sound: yap_sounds['_']});
      continue;
    }

    if (lowerChar.match(/[a-z.]/)) {
      yap_queue.push({letter: char, sound: yap_sounds[lowerChar]})
      continue; // skip characters that are not letters or periods
    }

    yap_queue.push({letter: char, sound: yap_sounds['_']})
  }

  function next_yap() {
    if (yap_queue.length === 0) {
      endCallback()
      return
    }
    let {sound, letter} = yap_queue.shift()
    sound.rate(Math.random() * rateVariance + baseRate)
    sound.volume(1)
    sound.once('end', next_yap)
    sound.play()
    sound.once('play', () => {
      letterCallback({sound, letter, length: yap_queue.length})
    })
  }

  next_yap();
}