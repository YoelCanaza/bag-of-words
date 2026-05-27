-- =============================================================================
-- Main.hs — Motor Principal del Pipeline MapReduce
-- =============================================================================
-- Universidad Nacional del Altiplano Puno — Ingeniería de Sistemas
-- Lenguajes de Programación — Unidad I: Big Data Funcional
--
-- Orquesta el pipeline completo:
--   Lazy I/O → MAP (tokenize) → FILTER (stopwords) → FOLD (BoW + sentiment)
--
-- Uso:
--   bag-of-words <archivo.txt>
--   bag-of-words <archivo.txt> <etiquetas.txt>   ← valida precisión (IMDB)
-- =============================================================================

module Main where

import System.Environment  (getArgs)
import System.IO           (hSetEncoding, stdout, utf8)
import Data.Map.Strict     (Map)

import Tokenizer  (tokenizeAll)
import BagOfWords (filterWords, buildBoW, topN)
import Sentiment  (classifyReview, accuracyReport)

-- ===========================================================================
-- PUNTO DE ENTRADA
-- ===========================================================================

main :: IO ()
main = do
    hSetEncoding stdout utf8
    args <- getArgs
    case args of
        [f]      -> runPipeline f Nothing
        [f, lf]  -> runPipeline f (Just lf)
        _        -> printUsage

printUsage :: IO ()
printUsage = mapM_ putStrLn
    [ "Uso:"
    , "  bag-of-words <archivo.txt>"
    , "  bag-of-words <archivo.txt> <etiquetas.txt>"
    , ""
    , "Casos de prueba:"
    , "  Micro-Data : data/processed/university_reviews.txt"
    , "  Big Data   : data/processed/imdb_reviews.txt  data/processed/imdb_labels.txt"
    ]

-- ===========================================================================
-- PIPELINE PRINCIPAL
-- ===========================================================================

runPipeline :: FilePath -> Maybe FilePath -> IO ()
runPipeline textFile mLabels = do

    printHeader textFile

    -- -----------------------------------------------------------------------
    -- CARGA — Evaluación Perezosa (Lazy I/O)
    -- readFile devuelve un String evaluado bajo demanda: el archivo se lee
    -- como stream continuo, sin cargar todo en RAM.
    -- Permite procesar gigabytes sin desbordar la memoria.
    -- -----------------------------------------------------------------------
    contents <- readFile textFile
    let rawLines = lines contents           -- lista lazy de líneas

    -- -----------------------------------------------------------------------
    -- FASE 1 — MAP: Tokenización
    -- Aplica tokenizeLine a CADA línea del corpus.
    -- Transforma :: String → [String] por cada documento.
    -- -----------------------------------------------------------------------
    let tokenized = tokenizeAll rawLines

    -- -----------------------------------------------------------------------
    -- FASE 2 — FILTER: Eliminación de Ruido
    -- Aplica el predicado isValidWord (longitud >= 4, no stopword)
    -- a cada lista de tokens de cada documento.
    -- -----------------------------------------------------------------------
    let cleaned = map filterWords tokenized

    -- -----------------------------------------------------------------------
    -- FASE 3a — FOLD: Bag of Words Global
    -- foldl sobre todos los documentos acumula frecuencias en un Map.
    -- Map.insertWith (+) combina sin variables de estado mutables.
    -- -----------------------------------------------------------------------
    let bow = buildBoW cleaned

    -- -----------------------------------------------------------------------
    -- FASE 3b — MAP + FOLD: Análisis de Sentimiento
    -- Usamos los tokens CRUDOS (tokenized, no cleaned) para que los negadores
    -- cortos como "no", "ni", "sin" (filtrados del BoW por longitud < 4)
    -- sí participen en el cálculo de polaridad.
    -- Para cada documento: foldl acumula polaridad con manejo de negación.
    -- -----------------------------------------------------------------------
    let sentLabels = map classifyReview tokenized

    -- -----------------------------------------------------------------------
    -- SALIDAS
    -- -----------------------------------------------------------------------
    showBoW       bow (length rawLines)
    showSentiment sentLabels

    case mLabels of
        Nothing         -> return ()
        Just labelsFile -> do
            labContents <- readFile labelsFile
            showAccuracy sentLabels (lines labContents)

    putStrLn ""
    putStrLn "✓ Pipeline completado."
    putStrLn (replicate 62 '─')

-- ===========================================================================
-- SALIDAS — funciones puramente de I/O (efectos en los bordes del sistema)
-- ===========================================================================

-- Utilitarios de formato
padR :: Int -> String -> String
padR n s = take n (s ++ repeat ' ')

pct :: Int -> Int -> String
pct _ 0 = "0"
pct n t = show (round (fromIntegral n * 100.0 / fromIntegral t :: Double) :: Int)

printHeader :: FilePath -> IO ()
printHeader fp = mapM_ putStrLn
    [ ""
    , replicate 62 '═'
    , "  MOTOR MAPREDUCE — BAG OF WORDS + ANÁLISIS DE SENTIMIENTO"
    , "  UNAP · Lenguajes de Programación · Unidad I"
    , replicate 62 '═'
    , "  Dataset : " ++ fp
    , replicate 62 '─'
    ]

showBoW :: Map String Int -> Int -> IO ()
showBoW bow total = do
    mapM_ putStrLn
        [ ""
        , "┌──────────────────────────────────────────────────────────────┐"
        , "│            BAG OF WORDS — TOP 20 PALABRAS GLOBALES           │"
        , "│  FILTER: stopwords + palabras <4 chars eliminadas            │"
        , "│  FOLD  : foldl + Map.insertWith (+) sobre corpus completo    │"
        , "└──────────────────────────────────────────────────────────────┘"
        , "  Total reseñas procesadas (Lazy I/O): " ++ show total
        , ""
        , "  #    Palabra                Frecuencia"
        , "  ──── ────────────────────── ──────────"
        ]
    mapM_ printRow (zip [(1::Int)..] (topN 20 bow))
  where
    printRow (i, (w, c)) =
        putStrLn $ "  " ++ padR 4 (show i) ++ " "
                        ++ padR 22 w        ++ " "
                        ++ show c

showSentiment :: [String] -> IO ()
showSentiment labels = do
    let total = length labels
        pos   = length $ filter (== "Positivo") labels
        neg   = length $ filter (== "Negativo") labels
        neu   = length $ filter (== "Neutro")   labels
    mapM_ putStrLn
        [ ""
        , "┌──────────────────────────────────────────────────────────────┐"
        , "│         ANÁLISIS DE SENTIMIENTO — DISTRIBUCIÓN GLOBAL         │"
        , "│  FOLD: polaridad acumulada por reseña con foldl puro          │"
        , "└──────────────────────────────────────────────────────────────┘"
        , "  Positivo : " ++ show pos ++ " reseñas  (" ++ pct pos total ++ "%)"
        , "  Negativo : " ++ show neg ++ " reseñas  (" ++ pct neg total ++ "%)"
        , "  Neutro   : " ++ show neu ++ " reseñas  (" ++ pct neu total ++ "%)"
        , "  ─────────────────────────────────────────"
        , "  Total    : " ++ show total ++ " reseñas"
        ]

showAccuracy :: [String] -> [String] -> IO ()
showAccuracy predicted actual = do
    let (correct, total, p) = accuracyReport predicted actual
    mapM_ putStrLn
        [ ""
        , "┌──────────────────────────────────────────────────────────────┐"
        , "│           VALIDACIÓN CONTRA ETIQUETAS REALES (IMDB)           │"
        , "└──────────────────────────────────────────────────────────────┘"
        , "  Predicciones correctas : " ++ show correct ++ " / " ++ show total
        , "  Precisión heurística   : " ++ show (round p :: Int) ++ "%"
        , "  (Clasificador por diccionario de polaridad — sin ML)"
        ]
