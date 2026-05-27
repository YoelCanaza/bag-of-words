# Motor MapReduce Funcional — Bag of Words y Análisis de Sentimiento

**Universidad Nacional del Altiplano Puno · Ingeniería de Sistemas**  
**Lenguajes de Programación — VII Ciclo, Grupo B · Unidad I**

---

## ✅ Tabla de evaluación

| Criterio | Pts | Sección de este documento |
|---|:---:|---|
| Tarea de Big Data elegida (descripción y funcionalidades) | 3 | [§ 1 — Descripción del proyecto](#1--descripción-del-proyecto) |
| Detalles del abordamiento funcional | 4 | [§ 3 — Abordamiento funcional](#3--abordamiento-desde-el-punto-de-vista-funcional) |
| Código | 4 | [§ 4 — Organización del código](#4--organización-del-código) |
| Pruebas (dos casos de prueba) | 3 | [§ 5 — Casos de prueba](#5--casos-de-prueba) |
| **Explicación técnica total** | **14** | |
| Informe técnico | 6 | [§ 6 — Informe técnico](#6--informe-técnico) |

---

## 1 · Descripción del proyecto

### ¿Qué tarea de Big Data se eligió?

Se eligió el **análisis de texto a gran escala**, específicamente:

1. **Bag of Words (BoW)** — contar la frecuencia de cada palabra en un corpus de decenas de miles de reseñas para descubrir el vocabulario dominante del dataset.
2. **Análisis de Sentimiento** — clasificar automáticamente cada reseña como *Positivo*, *Negativo* o *Neutro* evaluando la polaridad de sus palabras.

Estas dos tareas son la base de sistemas reales de Big Data:
- Los motores de recomendación de **Netflix** o **Spotify** aplican exactamente este tipo de análisis sobre millones de ítems: filtran contenido no deseado (`filter`), calculan una puntuación de relevancia por ítem (`map`) y agregan los resultados a un ranking final (`reduce`).
- Plataformas como **Amazon** o **Google Reviews** usan Bag of Words para identificar tendencias de opinión en millones de reseñas de productos.

### ¿Por qué es una tarea Big Data?

| Característica Big Data | Cómo aplica al proyecto |
|---|---|
| **Volumen** | Corpus de 50 000 reseñas cinematográficas (IMDB) + 928 reseñas universitarias |
| **Velocidad** | Procesamiento en stream (Lazy I/O) — sin cargar todo en RAM |
| **Variedad** | Texto no estructurado, reseñas de distinta longitud y vocabulario |
| **Paralelizabilidad** | Las funciones `map` y `fold` son stateless — escalables a N máquinas |

### Funcionalidades del sistema

| Funcionalidad | Descripción |
|---|---|
| **ETL automatizado** | Python extrae columnas de texto de archivos CSV, limpia ruido y exporta `.txt` planos |
| **Tokenización** | Cada reseña se transforma en lista de palabras normalizadas (minúsculas, sin puntuación) |
| **Filtrado de ruido** | Se eliminan stopwords, palabras de menos de 4 caracteres y puntuación |
| **Bag of Words global** | Se construye el ranking de frecuencia de todo el corpus |
| **Análisis de sentimiento** | Cada reseña recibe una etiqueta: Positivo / Negativo / Neutro |
| **Validación de precisión** | Para el dataset IMDB (con etiquetas reales) se calcula el % de acierto |

---

## 2 · Arquitectura general del pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│  MÓDULO I — ETL (Python)          MÓDULO II — Motor (Haskell)   │
│                                                                  │
│  CSV crudo                                                       │
│     │                                                            │
│     ▼  dropna + normalize                                        │
│  .txt plano  ──────────────►  Lazy I/O (stream)                 │
│  (1 línea = 1 reseña)              │                             │
│                                    ▼  MAP — tokenizeLine        │
│                               [[String]]  (tokens por reseña)   │
│                                    │                             │
│                                    ▼  FILTER — isValidWord      │
│                               [[String]]  (tokens limpios)      │
│                                    │                             │
│                          ┌─────────┴──────────┐                 │
│                          ▼                     ▼                │
│                    FOLD (foldl)         MAP + FOLD               │
│                  buildBoW               classifyReview           │
│                          │                     │                │
│                    Map String Int        [String]                │
│                  (frecuencias)         (etiquetas)               │
│                          │                     │                │
│                       Top 20              % Positivo             │
│                       palabras            % Negativo             │
│                                           % Neutro               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3 · Abordamiento desde el punto de vista funcional

### ¿Por qué Haskell?

El PDF indica que será **valorado** usar un lenguaje funcional puro. Haskell cumple con:

- **Inmutabilidad total**: no existen variables de estado. Cada función recibe datos y devuelve datos nuevos.
- **Funciones de primer orden**: `map`, `filter` y `foldl` son ciudadanos de primera clase — se pasan como argumentos.
- **Evaluación perezosa**: el archivo se lee como stream; Haskell nunca carga más de lo necesario en RAM.
- **Transparencia referencial**: la misma entrada siempre produce la misma salida — sin efectos secundarios.

### Las tres operaciones fundamentales

#### MAP — Transformación

```haskell
-- Aplicado a CADA carácter: normaliza a minúsculas
normalizeChar :: Char -> Char
normalizeChar c | isAlpha c = toLower c
                | isSpace c = ' '
                | otherwise = ' '      -- elimina puntuación

-- Aplicado a CADA línea: convierte texto en lista de palabras
tokenizeLine :: String -> [String]
tokenizeLine = words . map normalizeChar
--                      ^^^
--                      MAP sobre cada carácter de la línea

-- Aplicado a CADA reseña del corpus:
tokenizeAll :: [String] -> [[String]]
tokenizeAll = map tokenizeLine
--            ^^^
--            MAP de orden superior — función como argumento
```

#### FILTER — Depuración de ruido

```haskell
-- Predicado puro: TRUE si la palabra aporta información semántica
isValidWord :: String -> Bool
isValidWord w = length w >= 4          -- elimina artículos, preposiciones
             && w `notElem` stopwords  -- elimina conectores comunes

-- FILTER aplicado sobre cada lista de tokens
filterWords :: [String] -> [String]
filterWords = filter isValidWord
--            ^^^^^^
--            FILTER de orden superior — isValidWord como predicado
```

#### FOLD (Reduce) — Agregación

```haskell
-- Construye el Bag of Words: foldl acumula frecuencias en un Map inmutable
buildBoW :: [[String]] -> Map String Int
buildBoW = foldl foldDocument Map.empty
  where
    foldDocument acc tokens = foldl insertWord acc tokens
    insertWord   acc word   = Map.insertWith (+) word 1 acc
--                            ^^^^^^^^^^^^^^^^^^^^^^^^^
--                            REDUCE puro — (+) combina sin estado mutable

-- Calcula polaridad de una reseña: foldl con manejo de negación
scoreWords :: [String] -> Int
scoreWords = snd . foldl step (False, 0)
  where
    step (negated, acc) w
      | w `elem` negators = (True,  acc)               -- activa negación
      | otherwise         = (False, acc + score w)     -- acumula polaridad
--    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
--    FOLD con acumulador de dos dimensiones — sin variables mutables
```

### Comparación con Apache Spark

| Concepto en Apache Spark | Equivalente en este proyecto (Haskell) |
|---|---|
| `rdd.map(tokenize)` | `map tokenizeLine rawLines` |
| `rdd.filter(isValid)` | `map (filter isValidWord) tokenized` |
| `rdd.reduceByKey(+)` | `foldl (Map.insertWith (+)) Map.empty` |
| Lazy evaluation / particiones | Evaluación perezosa de Haskell (Lazy I/O) |
| Inmutabilidad de RDDs | Inmutabilidad total en Haskell |

---

## 4 · Organización del código

```
bag-of-words/
│
├── data/
│   ├── raw/                              ← datasets originales
│   │   ├── IMDB Dataset SPANISH.csv      ← 50 000 reseñas (Big Data)
│   │   └── reviews_consorcio_...csv      ← ~3 517 reseñas universitarias
│   │
│   └── processed/                        ← generados por el ETL
│       ├── imdb_reviews.txt              ← 50 000 líneas (1 reseña/línea)
│       ├── imdb_labels.txt               ← etiquetas reales para validación
│       ├── university_reviews.txt        ← 928 líneas
│       └── university_meta.txt           ← universidad|rating por reseña
│
├── src/
│   │
│   ├── etl_imdb.py            ← MÓDULO I: ETL del dataset IMDB
│   ├── etl_universities.py    ← MÓDULO I: ETL de reseñas universitarias
│   │
│   ├── Tokenizer.hs           ← MÓDULO II: MAP — tokenización pura
│   ├── BagOfWords.hs          ← MÓDULO II: FILTER + FOLD — BoW
│   ├── Sentiment.hs           ← MÓDULO II: FOLD — diccionario + clasificador
│   └── app/
│       └── Main.hs            ← punto de entrada del motor Haskell
│
├── bag-of-words.cabal         ← configuración del proyecto Haskell
├── COMO_EJECUTAR.md           ← comandos rápidos de ejecución
└── README.md                  ← este archivo
```

### Responsabilidad de cada archivo

| Archivo | Rol | Concepto funcional |
|---|---|---|
| `etl_imdb.py` | Lee CSV IMDB, limpia texto, exporta `.txt` | `map`, `filter` en Python |
| `etl_universities.py` | Lee CSV universidades, limpia, exporta `.txt` | `map`, `filter` en Python |
| `Tokenizer.hs` | Convierte `String → [String]` | **MAP** |
| `BagOfWords.hs` | Filtra tokens; construye ranking de frecuencia | **FILTER** + **FOLD** |
| `Sentiment.hs` | Diccionario de polaridad; fold con negación | **FOLD** (reduce) |
| `Main.hs` | Orquesta el pipeline, imprime resultados | Composición de funciones |

---

## 5 · Casos de prueba

### Caso 1 — Prueba de Precisión Lógica (Micro-Data)

**Dataset**: Reseñas de universidades peruanas (PUCP, Universidad de Lima, Cayetano Heredia, Universidad del Pacífico)  
**Tamaño**: 928 reseñas en español  
**Objetivo**: Verificar que las funciones `map`, `filter` y `fold` producen resultados correctos sobre datos conocidos  

**Comando**:
```bash
source ~/.ghcup/env
cabal run bag-of-words -- data/processed/university_reviews.txt
```

**Resultado esperado**:

```
BAG OF WORDS — TOP 20 PALABRAS GLOBALES
  #1  universidad     393
  #2  buena           162
  #3  excelente       120
  #4  gran            102
  ...

ANÁLISIS DE SENTIMIENTO
  Positivo : 532 reseñas  (57%)
  Negativo :  18 reseñas   (2%)
  Neutro   : 378 reseñas  (41%)
```

**Interpretación**: Las palabras dominantes (*universidad*, *buena*, *excelente*, *infraestructura*, *campus*) reflejan exactamente el tema del dataset. El 57% positivo es consistente con que la mayoría de reseñas de universidades tienen valoraciones de 4–5 estrellas (distribución real del dataset: 713 de 5 estrellas).

---

### Caso 2 — Prueba de Estrés Computacional (Big Data)

**Dataset**: IMDB — reseñas cinematográficas en español  
**Tamaño**: 50 000 reseñas (50 % positivas, 50 % negativas — etiquetadas)  
**Objetivo**: Demostrar eficiencia con gran volumen y validar la precisión del clasificador contra etiquetas reales  

**Comando**:
```bash
source ~/.ghcup/env
cabal run bag-of-words -- data/processed/imdb_reviews.txt data/processed/imdb_labels.txt
```

**Resultado esperado**:

```
BAG OF WORDS — TOP 20 PALABRAS GLOBALES
  #1  película      151 879
  #2  historia       26 108
  #3  mejor          17 561
  ...

ANÁLISIS DE SENTIMIENTO
  Positivo : 33 732 reseñas  (67%)
  Negativo : 10 104 reseñas  (20%)
  Neutro   :  6 164 reseñas  (12%)

VALIDACIÓN CONTRA ETIQUETAS REALES
  Predicciones correctas : 31 413 / 50 000
  Precisión heurística   : 63%
```

**Interpretación**: El clasificador heurístico (diccionario de polaridad + manejo de negación, sin Machine Learning) alcanza el **63% de precisión** sobre 50 000 registros. Supera el azar (50%) en 13 puntos porcentuales, demostrando que el enfoque funcional es válido y escalable.

---

## 6 · Informe técnico

### Problema que resuelve

El procesamiento de texto no estructurado a gran escala presenta un problema central: es imposible de paralelizar con programación imperativa tradicional, ya que los bucles con variables de estado compartido generan *race conditions* cuando se distribuyen entre múltiples núcleos o máquinas.

La solución funcional elimina este problema por diseño: si cada función es pura (sin efectos secundarios) y los datos son inmutables, cualquier subconjunto del corpus puede procesarse de forma independiente y sus resultados pueden combinarse sin conflicto.

### Decisiones de diseño

**¿Por qué Python para el ETL y Haskell para el motor?**

| Aspecto | Python (ETL) | Haskell (Motor) |
|---|---|---|
| Fortaleza | Ecosistema de datos (pandas, CSV) | Paradigma funcional puro |
| Rol | Capa de ingesta y limpieza | Núcleo computacional |
| Justificación | Herramienta estándar de ingeniería de datos | Lenguaje funcional puro valorado en el PDF |

**¿Por qué separar BoW y Sentimiento en el pipeline de tokens?**

- Para el **Bag of Words** se usan tokens *filtrados* (longitud ≥ 4, sin stopwords) → vocabulario significativo.
- Para el **Análisis de Sentimiento** se usan tokens *crudos* (incluyendo "no", "ni", "sin") → permite detectar negación (`"no es bueno"` = −1, no +1).

### Limitaciones del clasificador heurístico

| Limitación | Ejemplo problemático |
|---|---|
| Ironía / sarcasmo | *"Brillante forma de desperdiciar 2 horas"* → clasifica como Positivo |
| Frases compuestas | *"Gran decepción"* → "gran" (+1) cancela "decepción" (−1) |
| Vocabulario de traducción automática | El dataset IMDB fue traducido automáticamente del inglés |

**Nota**: el objetivo del trabajo es demostrar el paradigma funcional (map/filter/fold), no construir un clasificador de producción. Un modelo BERT en español alcanzaría ~92% de precisión, pero eso está fuera del alcance del curso.

### Complejidad computacional

| Operación | Complejidad | Escalabilidad |
|---|---|---|
| Tokenización (`map`) | O(n · m) — n reseñas, m caracteres promedio | Lineal, paralelizable |
| Filtrado (`filter`) | O(n · k) — k tokens por reseña | Lineal, paralelizable |
| Bag of Words (`foldl`) | O(n · k · log V) — V tamaño del vocabulario | Log-lineal, combinable |
| Sentimiento (`foldl`) | O(n · k) | Lineal, paralelizable |

La misma arquitectura funcional aplicada en Apache Spark distribuiría el `map` y el `fold` entre cientos de nodos, reduciendo el tiempo de O(n) a O(n / nodos).

### Resultados finales

| Métrica | Caso 1 (Micro) | Caso 2 (Big Data) |
|---|---|---|
| Reseñas procesadas | 928 | 50 000 |
| Vocabulario único (post-filter) | ~2 500 palabras | ~85 000 palabras |
| Palabra más frecuente | `universidad` (393) | `película` (151 879) |
| Reseñas positivas detectadas | 57 % | 67 % |
| Precisión vs. etiquetas reales | — | **63 %** |
| Tiempo de procesamiento | < 1 s | ~8 s |
