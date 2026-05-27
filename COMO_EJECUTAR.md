# Cómo ejecutar el proyecto

## Requisitos (ya instalados)
- Python → entorno virtual en `.venv/`
- Haskell GHC 9.6.7 + Cabal → instalado en `~/.ghcup/`

---

## Paso 1 — Activar Haskell (siempre al abrir terminal)

```bash
source ~/.ghcup/env
```

---

## Paso 2 — ETL: generar los archivos .txt (solo si no existen aún)

```bash
.venv/bin/python src/etl_universities.py
.venv/bin/python src/etl_imdb.py
```

Genera en `data/processed/`:
- `university_reviews.txt` — 928 reseñas
- `imdb_reviews.txt` — 50 000 reseñas
- `imdb_labels.txt` — etiquetas reales para validar precisión

---

## Paso 3 — Compilar el motor Haskell (solo la primera vez o tras cambios)

```bash
cabal build
```

---

## Pruebas

### Caso 1 — Micro-Data (reseñas universitarias)

```bash
cabal run bag-of-words -- data/processed/university_reviews.txt
```

### Caso 2 — Big Data (IMDB 50 000 reseñas + validación de precisión)

```bash
cabal run bag-of-words -- data/processed/imdb_reviews.txt data/processed/imdb_labels.txt
```

---

## Resultados esperados

| | Caso 1 · Micro-Data | Caso 2 · Big Data |
|---|---|---|
| Reseñas procesadas | 928 | 50 000 |
| Palabra #1 (BoW) | `universidad` | `película` |
| Positivo | ~57 % | ~67 % |
| Precisión vs etiquetas | — | ~63 % |
