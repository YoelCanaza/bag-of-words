# =============================================================================
# ETL MÓDULO I — Big Data: IMDB 50,000 Reseñas Cinematográficas (Español)
# =============================================================================
# Universidad Nacional del Altiplano Puno — Ingeniería de Sistemas
# Lenguajes de Programación — Unidad I: Big Data Funcional
#
# Responsabilidad: Extraer, limpiar y exportar las reseñas del dataset IMDB
# al formato plano (.txt) que consume el motor Haskell.
# Cada línea del archivo de salida = exactamente una reseña procesada.
# =============================================================================

import pandas as pd
import re
import os

# ---------------------------------------------------------------------------
# RUTAS
# ---------------------------------------------------------------------------
RAW_PATH   = os.path.join("data", "raw", "IMDB Dataset SPANISH.csv")
OUT_TEXT   = os.path.join("data", "processed", "imdb_reviews.txt")
OUT_LABELS = os.path.join("data", "processed", "imdb_labels.txt")

# ---------------------------------------------------------------------------
# FUNCIONES DE LIMPIEZA (estilo funcional — sin efectos secundarios)
# ---------------------------------------------------------------------------

def remove_internal_newlines(text: str) -> str:
    """Elimina saltos de línea internos que romperían el stream línea a línea."""
    return re.sub(r"[\r\n]+", " ", text)

def remove_noise_chars(text: str) -> str:
    """
    Elimina caracteres que corrompen la lectura del flujo:
    - Comillas dobles sueltas (rompen el parser CSV/línea)
    - Barras verticales y caracteres de control
    Conserva letras, dígitos, signos de puntuación básicos y tildes del español.
    """
    text = text.replace('"', "")          # comillas dobles
    text = re.sub(r"[|\\]", " ", text)    # pipes y barras
    text = re.sub(r"\s{2,}", " ", text)   # espacios múltiples → uno
    return text.strip()

def normalize(text: str) -> str:
    """Pipeline de normalización: aplica todas las transformaciones en orden."""
    return remove_noise_chars(remove_internal_newlines(str(text)))

# ---------------------------------------------------------------------------
# EXTRACCIÓN Y TRANSFORMACIÓN
# ---------------------------------------------------------------------------

def main():
    print("=" * 60)
    print("ETL — IMDB Dataset (Big Data, 50 000 reseñas)")
    print("=" * 60)

    # 1. EXTRACCIÓN — lectura del CSV
    print(f"\n[1/4] Leyendo: {RAW_PATH}")
    df = pd.read_csv(RAW_PATH)
    print(f"      Filas crudas : {len(df):,}")

    # 2. LIMPIEZA — dropna + filtro funcional sobre la columna relevante
    print("\n[2/4] Limpiando datos...")
    df = df.dropna(subset=["review_es"])

    # map funcional: aplica normalize a cada texto
    df["review_es"] = list(map(normalize, df["review_es"]))

    # filter funcional: descarta reseñas que quedaron demasiado cortas
    mask = list(map(lambda t: len(t) > 20, df["review_es"]))
    df = df[mask].reset_index(drop=True)
    print(f"      Filas limpias: {len(df):,}")

    # 3. EXPORTACIÓN — archivo de texto plano (una reseña por línea)
    print(f"\n[3/4] Exportando reseñas → {OUT_TEXT}")
    with open(OUT_TEXT, "w", encoding="utf-8") as f:
        for review in df["review_es"]:
            f.write(review + "\n")
    print(f"      Líneas escritas: {len(df):,}")

    # 4. EXPORTACIÓN DE ETIQUETAS — para validar precisión del clasificador
    print(f"\n[4/4] Exportando etiquetas → {OUT_LABELS}")
    with open(OUT_LABELS, "w", encoding="utf-8") as f:
        for label in df["sentimiento"]:
            f.write(str(label) + "\n")
    print(f"      Etiquetas escritas: {len(df):,}")

    # Distribución de sentimientos en el dataset
    dist = df["sentimiento"].value_counts().to_dict()
    print(f"\n      Distribución: {dist}")

    print("\n✓ ETL IMDB completado.\n")

if __name__ == "__main__":
    main()
