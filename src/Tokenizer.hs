-- =============================================================================
-- Tokenizer.hs — Módulo de Tokenización Pura
-- =============================================================================
-- Universidad Nacional del Altiplano Puno — Ingeniería de Sistemas
-- Lenguajes de Programación — Unidad I: Big Data Funcional
--
-- Responsabilidad: transformar cada línea de texto crudo en una lista de
-- tokens normalizados (minúsculas, sin puntuación).
--
-- Concepto funcional aplicado:
--   MAP — cada carácter se mapea a su versión normalizada,
--         luego cada línea se mapea a su lista de palabras.
-- =============================================================================

module Tokenizer (tokenizeLine, tokenizeAll) where

import Data.Char (toLower, isAlpha, isSpace)

-- ---------------------------------------------------------------------------
-- | Normaliza un solo carácter:
--   * letras del alfabeto (incluyendo tildes) → minúsculas
--   * espacios                                → conservar
--   * cualquier otro (puntuación, dígitos)    → reemplazar con espacio
-- ---------------------------------------------------------------------------
normalizeChar :: Char -> Char
normalizeChar c
    | isAlpha c || isSpanishAccent c = toLower c
    | isSpace c                      = ' '
    | otherwise                      = ' '

-- ---------------------------------------------------------------------------
-- | Caracteres del español que isAlpha no reconoce en todos los entornos.
-- ---------------------------------------------------------------------------
isSpanishAccent :: Char -> Bool
isSpanishAccent c = c `elem` ("áéíóúüñÁÉÍÓÚÜÑ" :: String)

-- ---------------------------------------------------------------------------
-- | Tokeniza una sola línea de texto:
--   1. MAP normalizeChar sobre cada carácter → texto limpio
--   2. words                                 → lista de tokens
-- ---------------------------------------------------------------------------
tokenizeLine :: String -> [String]
tokenizeLine = words . map normalizeChar
--             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
--             MAP explícito — transformación pura carácter a carácter

-- ---------------------------------------------------------------------------
-- | Tokeniza todas las líneas de un documento.
--   MAP de segundo orden: aplica tokenizeLine a cada elemento de la lista.
-- ---------------------------------------------------------------------------
tokenizeAll :: [String] -> [[String]]
tokenizeAll = map tokenizeLine
--            ^^^^^^^^^^^^^^^^
--            MAP de orden superior — función como argumento
