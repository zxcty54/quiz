# Universal Question Format — Ek Hi Sach

Ye file MockTester ke saare sawalon ka **canonical format** hai.
Har exam/folder (BSSC, BPSC, SI, Maths, Reasoning...) ke liye yahi ek format chalega.
App ka renderer (`LatexText`) aur data isi format ko maan kar chalte hai —
per-question hack nahi, ek hi rule sab par.

## 1. Canonical JSON

Har question file ek JSON array hoti hai. Har sawal thik inhi keys me (isi order me) hoga:

| Key | Type | Matlab |
|-----|------|--------|
| `p_id` | string | Unique ID, jaise `bssc_cgl_reasoning_set1_12` |
| `qe` | string | English sawal |
| `qh` | string | Hindi sawal (na ho to `qe` jaisa) |
| `se` | string[] | Optional — puzzle/passage ke statements (English) |
| `sh` | string[] | Optional — wahi statements Hindi me |
| `oe` | string[4] | English options — hamesha 4 |
| `oh` | string[4] | Hindi options (na ho to `oe` jaisi copy) |
| `a` | int | Sahi jawab ka index (0–3) |
| `e` | string | Explanation (boilerplate bina: "Detailed Explanation:" nahi likhte) |

`se/sh` sirf tab jab sawal kisi shared passage/puzzle par ho.
**Puzzle rule:** har us sawal me pura setup paragraph repeat hoga jisse sawal banta hai —
setup sirf pehle sawal me rakh kar baaki ko adhoora mat chhodo.

## 2. Text ke Andar ke Niyam (sabse zaroori)

1. **Topic sawal ke andar NAHI hoga.** `<b>Topic:</b>` ya `<b>Coding-Decoding:</b>`
   jaisa chipka heading kabhi nahi. Topic app ko chahiye hi nahi.
2. **Formula sirf `$...$` ke andar.** Chemistry/physics/math ka har formula dollar me:
   `$H_2SO_4$`, `$E = mc^2$`, `$\frac{1}{2}$`, `$\sqrt{x}$`, `$\Delta x \geq 0$`
   - Samikaran ka teer: `\rightarrow` ( `->` ya `→` nahi)
   - Greek akshar LaTeX me: `\theta \pi \lambda \Delta` (kachche `θ π λ` nahi)
   - Unicode subscript/superscript bilkul nahi: `H₂SO₄`, `cm²`, `10⁻³` ❌
3. **Reasoning ke chinh ganit NAHI hai.** Blood relation, coding, series me
   `$ # @ % < >` akele chinh hai — inhe `$...$` me kabhi mat bandho.
   `P $ Q` me dollar akela rahega, app use khud pehchan kar text ki tarah dikhayega.
4. **Percent, unit, paisa sadharann text me:** `50%`, `Rs. 500`, `5 km` —
   dollar me nahi.
5. Bold/italic ke liye `<b>...</b>` chalega, lekin sawal ke beech ka bold shabd
   (jaise `<b>'FRUGAL'</b> ka vilom`) sawal ka hissa hai, topic nahi — use rehne do.
6. Har text single line ki string ho. Asli newline ki jagah space.

## 3. AI Se Sawal Banwane Wala Master Prompt

```
Tum MockTester ke liye exam questions bana rahe ho.
Output SIRF ek valid JSON array hoga — koi extra text, koi markdown fence nahi.

Har question ka format (key order bilkul yahi):
{"p_id": "...", "qe": "...", "qh": "...", "oe": ["...","...","...","..."],
 "oh": ["...","...","...","..."], "a": 0, "e": "..."}
(Passage/puzzle ho to qe ke baad "se": [...], "sh": [...] jodo.)

Niyam:
1. Topic sawal ke text me mat likho — koi <b>Topic:</b> wali line nahi.
2. Formula hamesha $...$ me: $H_2SO_4$, $x^2 + 3x = 0$, $\frac{a}{b}$, $\rightarrow$.
   Unicode ₂ ₄ ² θ π √ kabhi nahi.
3. Reasoning ke chinh ($ # @ < >) ganit nahi — $...$ me mat bandho.
4. Puzzle/passage ka pura setup us group ke HAR sawal me pura-pura repeat karo.
5. Options hamesha 4, "a" sahi wale ka index (0-3), explanation 2-3 line me,
   "Detailed Explanation:" jaisi shuruaat ke bina.
6. Percent/unit/paisa plain text me: 50%, Rs. 500.
7. qh me Devanagari Hindi, oe/oh me wahi options dono bhasha me.
```

## 4. Tool — normalize_questions

Purani/mili-juli files ko canonical banane ka deterministic tool:

```
python3 tools/question_format/normalize_questions.py <source_folder> <output_folder>
```

Khud kya theek karta hai:
- Key order canonical (`p_id, qe, qh, se, sh, oe, oh, a, e`), purani key
  (`o`, `options`, `answer`, `answerIndex`...) ka conversion
- Shuruaat ka chipka topic strip (colon wala/'topic' se shuru — sawal ke beech
  ka bold shabd nahi kaat ta)
- Unicode formula (`H₂SO₄`, `cm²`, `mm⁻³`, akele `Δ λ π`) ko `$...$` LaTeX me
- `$...$` ke andar bache unicode ki safai, `->` ko `\rightarrow`, tuti JSON ki
  do jaani-pehchani aam galtiyon ki repair (adhuri `"o":3"` line, aakhir ka `"]`)

Khud nahi karta (report me FLAG karke chhodta hai, `normalization_report.json` me milega):
- Reasoning wala akela `$` (app ka renderer use runtime pe surakshit dikhata hai)
- Options 4 se kam/jyada, khaali explanation, akela bhatka `$`

Tool idempotent hai — dusri baar chalane par kuch nahi badalta,
toh hamesha safely dobara chalaya ja sakta hai.

## 5. App Ki Taraf Ka Sach

- `Question.fromJson` purane saare format (`o`/`oe`, letter/index answer) padh leta hai,
  aur `getText` chipka topic (upar wale niyam se) hata deta hai.
- `LatexText` ek hi universal renderer hai: jo `$...$` asal ganit hai (andar
  `\ ^ _ { }` ya ank + chinh) wahi KaTeX banta hai — baki `$` sadharan text.
  Matlab galat data bhi screen par tutega nahi, lekin saaf data hi asil ilaaj hai.
