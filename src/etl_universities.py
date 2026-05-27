# =============================================================================
# ETL MÓDULO I — Micro-Data: Reseñas de Universidades Peruanas
# =============================================================================
# Universidad Nacional del Altiplano Puno — Ingeniería de Sistemas
# Lenguajes de Programación — Unidad I: Big Data Funcional
#
# Responsabilidad: Extraer, limpiar y exportar las reseñas universitarias
# al formato plano (.txt) que consume el motor Haskell.
# Cada línea del archivo de salida = exactamente una reseña procesada.
# =============================================================================

import pandas as pd
import re
import os

# ---------------------------------------------------------------------------
# RUTAS
# ---------------------------------------------------------------------------
RAW_PATH = os.path.join("data", "raw", "reviews_consorcio_universidades_pe_06082025.csv")
OUT_TEXT = os.path.join("data", "processed", "university_reviews.txt")
OUT_META = os.path.join("data", "processed", "university_meta.txt")

# ---------------------------------------------------------------------------
# FUNCIONES DE LIMPIEZA (estilo funcional — sin efectos secundarios)
# ---------------------------------------------------------------------------

def remove_internal_newlines(text: str) -> str:
    """Elimina saltos de línea internos que romperían el stream línea a línea."""
    return re.sub(r"[\r\n]+", " ", text)

def remove_noise_chars(text: str) -> str:
    """
    Elimina caracteres que corrompen la lectura del flujo.
    Conserva letras, dígitos, puntuación básica y tildes del español.
    """
    text = text.replace('"', "")
    text = re.sub(r"[|\\]", " ", text)
    text = re.sub(r"\s{2,}", " ", text)
    return text.strip()

def normalize(text: str) -> str:
    """Pipeline de normalización: aplica todas las transformaciones en orden."""
    return remove_noise_chars(remove_internal_newlines(str(text)))

def is_valid(text: str) -> bool:
    """Predicate: descarta reseñas vacías o excesivamente cortas."""
    return len(text.strip()) > 15

# ---------------------------------------------------------------------------
# EXTRACCIÓN Y TRANSFORMACIÓN
# ---------------------------------------------------------------------------

def main():
    print("=" * 60)
    print("ETL — Reseñas Universitarias Peruanas (Micro-Data)")
    print("=" * 60)

    # 1. EXTRACCIÓN
    print(f"\n[1/4] Leyendo: {RAW_PATH}")
    df = pd.read_csv(RAW_PATH)
    print(f"      Filas crudas : {len(df):,}")

    # 2. LIMPIEZA
    print("\n[2/4] Limpiando datos...")
    df = df.dropna(subset=["review_text"])

    # map funcional: normaliza cada texto
    df["review_text"] = list(map(normalize, df["review_text"]))

    # filter funcional: descarta reseñas vacías o muy cortas
    mask = list(map(is_valid, df["review_text"]))
    df = df[mask].reset_index(drop=True)
    print(f"      Filas limpias: {len(df):,}")

    # 3. EXPORTACIÓN — una reseña por línea
    print(f"\n[3/4] Exportando reseñas → {OUT_TEXT}")
    with open(OUT_TEXT, "w", encoding="utf-8") as f:
        for review in df["review_text"]:
            f.write(review + "\n")
    print(f"      Líneas escritas: {len(df):,}")

    # 4. EXPORTACIÓN DE METADATA — universidad y rating para contexto
    #    Formato: <name_place>|<rating>
    #    Permite correlacionar la clasificación de sentimiento con el rating real.
    print(f"\n[4/4] Exportando metadata → {OUT_META}")
    with open(OUT_META, "w", encoding="utf-8") as f:
        for _, row in df.iterrows():
            place  = normalize(str(row.get("name_place", "N/A")))
            rating = str(row.get("rating", "N/A"))
            f.write(f"{place}|{rating}\n")
    print(f"      Registros de metadata: {len(df):,}")

    # Distribución de ratings
    if "rating" in df.columns:
        dist = df["rating"].value_counts().sort_index().to_dict()
        print(f"\n      Distribución ratings: {dist}")

    # Universidades cubiertas
    if "name_place" in df.columns:
        places = df["name_place"].dropna().unique()
        print(f"\n      Universidades en el dataset ({len(places)}):")
        for p in sorted(places)[:10]:
            print(f"        · {p}")
        if len(places) > 10:
            print(f"        ... y {len(places) - 10} más")

    print("\n✓ ETL Universidades completado.\n")

if __name__ == "__main__":
    main()
