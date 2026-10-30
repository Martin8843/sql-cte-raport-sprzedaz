
-- Skrypt SQL – Raporty Sprzedażowe



-- =========================================================================
-- RAPORT NR 1: Sprzedaż pracowników w podziale na ostatnie 12 miesięcy
-- (Uwzględnia pracowników bez sprzedaży w danym miesiącu – zwraca 0)
-- =========================================================================

WITH mies_startowy AS (
    -- Wyznacza początek ostatniego pełnego miesiąca (pomijając bieżący)
    SELECT TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM') AS p_dzien_ost_mies FROM DUAL
),
list_mies AS (
    -- Generuje ciąg 12 miesięcy wstecz
    SELECT ADD_MONTHS((SELECT p_dzien_ost_mies FROM mies_startowy), - (12 - LEVEL)) AS start_mies 
    FROM DUAL
    CONNECT BY LEVEL <= 12
),
sprzedaz_per_prac_mies AS (
    -- Agreguje sprzedaż per pracownik i miesiąc w zadanym zakresie dat
    SELECT
        s.id_pracownika,
        TRUNC(s.data_sprzedazy, 'MM') AS start_miesiaca,
        COUNT(*) AS liczba_trans,
        SUM(s.wartosc) AS calk_wart,
        AVG(s.wartosc) AS srednia,
        MAX(s.wartosc) AS maksymalna_wart
    FROM Sprzedaz s
    CROSS JOIN mies_startowy p    
    WHERE s.data_sprzedazy >= ADD_MONTHS(p.p_dzien_ost_mies, -11)
      AND s.data_sprzedazy <  ADD_MONTHS(p.p_dzien_ost_mies, 1)
    GROUP BY s.id_pracownika, TRUNC(s.data_sprzedazy, 'MM')
)
SELECT
    pr.id_pracownika,
    pr.imie || ' ' || pr.nazwisko                      AS pracownik,
    TO_CHAR(m.start_mies, 'YYYY-MM')                   AS miesiac,
    NVL(sa.liczba_trans, 0)                            AS liczba_transakcji,
    NVL(ROUND(sa.calk_wart, 2), 0)                     AS wartosc_miesieczna,
    NVL(ROUND(sa.srednia, 2), 0)                       AS srednia_transakcji,
    NVL(ROUND(sa.maksymalna_wart, 2), 0)               AS max_transakcja
FROM Pracownicy pr
CROSS JOIN list_mies m
LEFT JOIN sprzedaz_per_prac_mies sa
  ON sa.id_pracownika = pr.id_pracownika
 AND sa.start_miesiaca = m.start_mies
ORDER BY pr.nazwisko, pr.imie, m.start_mies;


-- RAPORT NR 2: Najlepsi sprzedawcy w każdym regionie (Luty 2024)
-- (Wykorzystuje funkcję analityczną RANK() oraz zakres dat przyjazny indeksom)
-- =========================================================================

WITH sprzedaz_luty AS (
    SELECT 
        p.id_region,
        r.nazwa AS region,
        p.id_pracownika,
        p.imie || ' ' || p.nazwisko AS pracownik,
        SUM(s.wartosc) AS sum_luty
    FROM Sprzedaz s
    JOIN Pracownicy p ON s.id_pracownika = p.id_pracownika
    JOIN Regiony r ON p.id_region = r.id_region
    -- Użycie zakresu dat pozwala bazie efektywnie wykorzystać indeks na kolumnie daty
    WHERE s.data_sprzedazy >= TO_DATE('2024-02-01', 'YYYY-MM-DD') 
      AND s.data_sprzedazy <  TO_DATE('2024-03-01', 'YYYY-MM-DD')
    GROUP BY p.id_region, r.nazwa, p.id_pracownika, p.imie, p.nazwisko
)
SELECT id_region, region, id_pracownika, pracownik, sum_luty
FROM (
    SELECT sl.*,
           -- RANK() obsługuje remisy (jeśli kilku sprzedawców ma ten sam najlepszy wynik)
           RANK() OVER (PARTITION BY id_region ORDER BY sum_luty DESC) AS pozycja_rank
    FROM sprzedaz_luty sl
) t
WHERE pozycja_rank = 1
ORDER BY region, pracownik;