# Guía de Exposición — Código del Proyecto

> **Para la presentación**: sigue el orden de esta guía. Cada sección indica qué archivo abrir y qué líneas mostrar.

---

## Idea central (30 segundos)

> "Tenemos 50 000 reseñas de texto. El problema es procesarlas sin variables compartidas,  
> sin bucles con estado, sin condiciones de carrera. La solución: programación funcional pura —  
> `map`, `filter` y `fold`. El mismo modelo que usa Apache Spark, pero implementado en Haskell."

---

## PASO 1 — Python ETL · `src/etl_universities.py`

**¿Qué hace?** Lee el CSV crudo, limpia el texto y exporta un `.txt` con una reseña por línea.  
**¿Por qué Python aquí?** Es la capa de ingesta (ETL). Haskell es el motor de procesamiento.

### Abrir: líneas 27–43 — funciones puras de limpieza

```python
def remove_internal_newlines(text: str) -> str:      # línea 27
    return re.sub(r"[\r\n]+", " ", text)

def remove_noise_chars(text: str) -> str:             # línea 31
    text = text.replace('"', "")
    ...
    return text.strip()

def normalize(text: str) -> str:                      # línea 41
    return remove_noise_chars(remove_internal_newlines(str(text)))
```

**Punto funcional**: `normalize` es **composición de funciones** — igual que en Haskell (`f . g`). No tiene variables de estado: recibe un texto, devuelve un texto limpio. Siempre.

### Abrir: líneas 68–72 — map y filter en Python

```python
df["review_text"] = list(map(normalize, df["review_text"]))   # línea 68
mask = list(map(is_valid, df["review_text"]))                  # línea 71
df = df[mask].reset_index(drop=True)
```

**Punto funcional**: `map(normalize, ...)` aplica la función a **cada elemento** sin un bucle `for`. `is_valid` es un predicado puro — solo devuelve `True` o `False`. Esto ya es programación funcional en Python.

---

## PASO 2 — Tokenización · `src/Tokenizer.hs`

**¿Qué hace?** Convierte cada línea de texto en una lista de palabras normalizadas.

### Abrir: líneas 25–29 — función pura `normalizeChar`

```haskell
normalizeChar :: Char -> Char          -- línea 25
normalizeChar c
    | isAlpha c || isSpanishAccent c = toLower c
    | isSpace c                      = ' '
    | otherwise                      = ' '   -- puntuación → espacio
```

**Punto funcional**: tipo `Char -> Char` — recibe un carácter, devuelve uno. Sin efectos secundarios. **Transparencia referencial**: `normalizeChar '!'` siempre será `' '`, en cualquier máquina, en cualquier momento.

### Abrir: líneas 42–43 — MAP explícito

```haskell
tokenizeLine :: String -> [String]     -- línea 42
tokenizeLine = words . map normalizeChar
--                      ^^^
--                      MAP sobre cada carácter de la línea
```

`map normalizeChar` aplica la función a **cada carácter** del String. El `.` es composición funcional — encadena transformaciones sin guardar resultados intermedios.

### Abrir: líneas 51–52 — MAP de orden superior

```haskell
tokenizeAll :: [String] -> [[String]]  -- línea 51
tokenizeAll = map tokenizeLine
```

`tokenizeLine` se pasa **como argumento** a `map`. Esto es una **función de primer orden** — el concepto central del paradigma funcional que menciona el PDF.

---

## PASO 3 — Bag of Words · `src/BagOfWords.hs`

**¿Qué hace?** Filtra palabras de ruido y construye el ranking de frecuencia de todo el corpus.

### Abrir: líneas 50–51 — predicado puro

```haskell
isValidWord :: String -> Bool          -- línea 50
isValidWord w = length w >= 4 && w `notElem` stopwords
```

Función pura: recibe una palabra, devuelve `True` o `False`. No modifica nada.

### Abrir: líneas 59–60 — FILTER de orden superior

```haskell
filterWords :: [String] -> [String]    -- línea 59
filterWords = filter isValidWord
--            ^^^^^^^^^^^^^^^^^^^
--            FILTER — isValidWord pasada como predicado (función de primer orden)
```

`isValidWord` se pasa como argumento a `filter`. Esto elimina stopwords y palabras cortas de **todas las reseñas** sin un solo bucle.

### Abrir: líneas 75–84 — FOLD (el corazón del MapReduce)

```haskell
buildBoW :: [[String]] -> Map String Int   -- línea 75
buildBoW = foldl foldDocument Map.empty
  where
    foldDocument acc tokens = foldl insertWord acc tokens
    insertWord   acc word   = Map.insertWith (+) word 1 acc
--                            ^^^^^^^^^^^^^^^^^^^^^^^^
--                            REDUCE puro: (+) combina sin estado compartido
```

**Este es el equivalente de `reduceByKey` de Apache Spark.**

- `foldl` recorre el corpus completo.
- El acumulador `Map.empty` se va llenando con frecuencias.
- `Map.insertWith (+) word 1` suma 1 a la frecuencia de cada palabra.
- **Nunca hay una variable `contador = 0` que se modifica** — el nuevo valor se pasa como argumento en cada iteración.

### Abrir: línea 91 — composición de funciones

```haskell
topN n = take n . sortBy (comparing (Down . snd)) . Map.toList   -- línea 91
```

Tres funciones encadenadas con `.`: convierte el Map a lista → ordena por frecuencia descendente → toma los primeros N. Sin variables temporales.

---

## PASO 4 — Análisis de Sentimiento · `src/Sentiment.hs`

**¿Qué hace?** Clasifica cada reseña como Positivo / Negativo / Neutro evaluando la polaridad de sus palabras.

### Abrir: líneas 35–46 — normalización de tildes (MAP)

```haskell
stripAccent :: Char -> Char            -- línea 35
stripAccent 'á' = 'a'; stripAccent 'é' = 'e'
...                                    -- pattern matching puro

normalizeToken :: String -> String     -- línea 45
normalizeToken = map stripAccent
```

`map stripAccent` aplica la transformación a cada carácter. Así `"película"` y `"pelicula"` se tratan igual al buscar en el diccionario.

### Abrir: líneas 200–204 — diccionario como dato

```haskell
sentimentDict :: Map String Int        -- línea 200
sentimentDict = Map.union positiveMap negativeMap
  where
    positiveMap = Map.fromList [(w,  1) | w <- positiveWords]
    negativeMap = Map.fromList [(w, -1) | w <- negativeWords]
```

El diccionario es **datos puros** — una función sin argumentos que devuelve siempre el mismo `Map`. ~200 palabras positivas (+1) y negativas (−1).

### Abrir: líneas 218–233 — FOLD con negación (el más importante de Sentiment)

```haskell
scoreWords :: [String] -> Int          -- línea 218
scoreWords ws = snd $ foldl step (False, 0) ws
  where
    step (negated, acc) w
      | w `elem` negators =            -- "no", "nunca", "jamás"...
          (True, acc)                  -- activa bandera de negación
      | otherwise =
          let value = Map.findWithDefault 0 (normalizeToken w) sentimentDict
              score = if negated && value /= 0 then -value else value
          in (False, acc + score)
```

**Aquí se ve la potencia del FOLD**:

| Iteración | Palabra | Estado `(negated, acc)` |
|---|---|---|
| 1 | `"no"` | `(True, 0)` ← activa negación |
| 2 | `"fue"` | `(False, 0)` ← sin valor en dict |
| 3 | `"buena"` | `(False, -1)` ← +1 invertido a −1 |

`"no fue buena"` → score −1 → **Negativo** ✓  
`"fue buena"` → score +1 → **Positivo** ✓

El acumulador es un **par `(Bool, Int)`** — no hay ninguna variable mutable. El estado se pasa explícitamente en cada paso del fold.

### Abrir: líneas 238–242 — clasificación pura

```haskell
classifyScore :: Int -> String         -- línea 238
classifyScore score
    | score > 0 = "Positivo"
    | score < 0 = "Negativo"
    | otherwise  = "Neutro"
```

Función pura total: mismo score → misma etiqueta, siempre.

---

## PASO 5 — Pipeline principal · `src/app/Main.hs`

**Mostrar líneas 64–95** — aquí se ve todo el pipeline junto, en 5 líneas de lógica:

```haskell
contents  <- readFile textFile          -- línea 64 — Lazy I/O (stream)
let rawLines  = lines contents          -- línea 65
let tokenized = tokenizeAll rawLines    -- línea 72 — FASE 1: MAP
let cleaned   = map filterWords tokenized  -- línea 79 — FASE 2: FILTER
let bow       = buildBoW cleaned        -- línea 86 — FASE 3a: FOLD → BoW
let sentLabels = map classifyReview tokenized  -- línea 95 — FASE 3b: MAP+FOLD
```

**Punto clave para la exposición**:

> "Noten que `tokenized`, `cleaned`, `bow` y `sentLabels` son **valores**, no variables.  
> Nunca se modifican. Esto es exactamente lo que hace Apache Spark con sus RDDs —  
> colecciones inmutables que se transforman en cadena."

**Lazy I/O** (línea 64): `readFile` no carga 50 000 reseñas en RAM. Haskell las lee como un stream continuo, evaluando solo lo necesario. Esto es lo que permite procesar gigabytes sin desbordar la memoria.

---

## Resumen visual para mostrar en la exposición

```
CSV crudo
   │
   ▼  map(normalize)  ← Python ETL
.txt (1 línea = 1 reseña)
   │
   ▼  readFile        ← Lazy I/O
[String]  (50 000 líneas)
   │
   ▼  map tokenizeLine              ← MAP
[[String]]  (tokens por reseña)
   │
   ▼  map (filter isValidWord)      ← FILTER
[[String]]  (tokens limpios)
   │
   ├──► foldl insertWord            ← FOLD → Bag of Words
   │         Map String Int
   │         "película" → 151 879
   │
   └──► map (foldl step)            ← FOLD → Sentimiento
             ["Positivo","Negativo","Neutro",...]
             Precisión: 63 % sobre 50 000 reseñas
```
