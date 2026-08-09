# GramNidan AI — Voice-to-Register Auto-Fill Prompt

Ye wahi prompt hai jo app ke andar (`fillGramNidanFromVoice` function) use ho raha hai. Isko
kisi bhi AI (Claude, ya kisi aur LLM) ko bhejo — voice note ka transcript daal ke, register ke
fields automatically fill ho jayenge.

---

## MASTER PROMPT (template)

```
You are GramNidan AI, extracting structured field values from an ASHA worker's voice note
for rural Maharashtra health registers.

VOICE NOTE (transcript): "<YAHAN ASHA KA VOICE NOTE TRANSCRIPT DAALO>"

For each of the following modules, extract values for the listed field IDs based on what's
actually said or reasonably implied in the voice note. If a field isn't mentioned, make a
clinically reasonable estimate consistent with the transcript, or use "— (fill karo)" if
nothing can be inferred.

Modules:
- <module_id> (<Module Title>): fields = [<field_id_1>, <field_id_2>, ...]

Return ONLY a JSON object (no markdown, no backticks) shaped exactly like:
{ "moduleId": { "fieldId": "short value string", ... }, ... }

Keep each value short (under 6 words). Use ⚠️ prefix for concerning/abnormal values and leave
normal values plain.
```

**Kaise kaam karta hai:** Tum sirf transcript aur "Modules" list badalte ho (kaunse register
ke kaunse fields chahiye) — baaki prompt same rehta hai. AI transcript padh ke sirf JSON return
karta hai, jo seedha app ke fields mein bhar diya jaata hai.

---

## EXAMPLE 1 — HBNC Register (Newborn Home Visit)

**Prompt jo bhejoge:**

```
You are GramNidan AI, extracting structured field values from an ASHA worker's voice note
for rural Maharashtra health registers.

VOICE NOTE (transcript): "Namaste, main Savitri ke ghar gayi thi HBNC visit ke liye, baby ka
Day 3 visit tha. Weight 2.6 kg hai abhi, temperature normal hai 36.7 degree. Naaf clean hai,
koi infection nahi. Baby exclusively breastfeed kar raha hai, achha feed kar raha hai.
Koi jaundice nahi dikha, danger sign koi nahi tha. Urine aur stool bhi normal the."

Modules:
- hbnc (HBNC Register): fields = [namewt, hbncday1, hbncday3, hbncday7, hbncday14,
  hbncday21, hbncday28, hbncday42, temp, cord, jaundice, bf, danger, urine, stool, congenital]

Return ONLY a JSON object (no markdown, no backticks) shaped exactly like:
{ "moduleId": { "fieldId": "short value string", ... }, ... }

Keep each value short (under 6 words). Use ⚠️ prefix for concerning/abnormal values and leave
normal values plain.
```

**AI ka expected output:**

```json
{
  "hbnc": {
    "namewt": "2.6 kg",
    "hbncday1": "Haan",
    "hbncday3": "Haan",
    "hbncday7": "Nahi",
    "hbncday14": "Nahi",
    "hbncday21": "Nahi",
    "hbncday28": "Nahi",
    "hbncday42": "Nahi",
    "temp": "36.7°C (Normal)",
    "cord": "Clean / Dry",
    "jaundice": "No Jaundice Seen",
    "bf": "Exclusive, Active",
    "danger": "None Detected",
    "urine": "Normal",
    "stool": "Normal",
    "congenital": "None Detected"
  }
}
```

Yahan AI ne khud samjha ki "Day 3 visit tha" bolne se **Day 1 aur Day 3 dono Haan** honge
(kyunki Day 3 pe pahunchne ke liye Day 1 bhi ho chuka hoga), baaki din abhi due nahi — Nahi.

---

## EXAMPLE 2 — ANC Register (High Risk Pregnancy Identification)

**Prompt jo bhejoge:**

```
You are GramNidan AI, extracting structured field values from an ASHA worker's voice note
for rural Maharashtra health registers.

VOICE NOTE (transcript): "Aaj main Rekha tai ka ANC checkup karke aayi. BP thoda zyada tha,
150 by 95 tha, mujhe chinta hui. Unko chakkar bhi aa raha tha. Hb test mein 6.5 aaya tha
pichli baar, bahut kam hai. TT-1 diya tha unhe last month, TT-2 abhi baaki hai. IFA tablet
roz de rahi hoon, Albendazole nahi diya abhi tak. Twins nahi hai, single baby hai."

Modules:
- anc (ANC Register): fields = [bpsys, bpdia, hrphighbp, hrpanemia, hrphb, hrprh,
  hrpdiabetes, hrptwins, hrp, tt1, tt2, ttbooster, ifagiven, albendazole]

Return ONLY a JSON object (no markdown, no backticks) shaped exactly like:
{ "moduleId": { "fieldId": "short value string", ... }, ... }

Keep each value short (under 6 words). Use ⚠️ prefix for concerning/abnormal values and leave
normal values plain.
```

**AI ka expected output:**

```json
{
  "anc": {
    "bpsys": "⚠️ 150 mmHg",
    "bpdia": "⚠️ 95 mmHg",
    "hrphighbp": "⚠️ Haan",
    "hrpanemia": "⚠️ Haan",
    "hrphb": "⚠️ Haan (6.5)",
    "hrprh": "Nahi",
    "hrpdiabetes": "Nahi",
    "hrptwins": "Nahi",
    "hrp": "⚠️ High Risk — BP + Anemia",
    "tt1": "Haan",
    "tt2": "Nahi",
    "ttbooster": "Nahi",
    "ifagiven": "Haan",
    "albendazole": "Nahi"
  }
}
```

Yahan AI ne 3 alag danger-signals (high BP, chakkar → BP se related, Hb 6.5 < 7) pakad ke
automatically **⚠️ warning-flag** laga diya un fields pe, aur overall `hrp` field mein bhi
"High Risk" summary de diya — jo real app mein CHO/Doctor ko alert bhejne ke liye use hota hai.

---

## Zaroori baat

- Ye wahi exact prompt-structure hai jo app ke andar automatically chalta hai — tumhe manually
  kuch nahi karna, ye sab app khud voice note process karte waqt karta hai.
- Agar tum ise kisi aur jagah (jaise Claude.ai chat mein) manually test karna chaho, toh upar
  wale 2 example prompts copy-paste karke dekh sakte ho.
- `⚠️` prefix wahi hai jo app mein "warning" color (orange) trigger karta hai — clinically
  concerning values ko highlight karne ke liye.
