SET SERVEROUTPUT ON;

-- 1. Czyszczenie
DROP TRIGGER trg_check_wiek;
DROP TRIGGER trg_auto_przebieg;

DROP PACKAGE BODY pkg_wynajem;
DROP PACKAGE pkg_wynajem;
DROP PACKAGE BODY pkg_zwroty;
DROP PACKAGE pkg_zwroty;
DROP PACKAGE BODY pkg_raporty;
DROP PACKAGE pkg_raporty;

DROP SEQUENCE seq_wypozyczenia;
DROP SEQUENCE seq_faktury;
DROP SEQUENCE seq_kontrakty;

DROP TABLE kontrakty CASCADE CONSTRAINTS;
DROP TABLE faktury_vat CASCADE CONSTRAINTS;
DROP TABLE protokoly_uszkodzen CASCADE CONSTRAINTS;
DROP TABLE wypozyczenia CASCADE CONSTRAINTS; 
DROP TABLE kierowcy_firmowi CASCADE CONSTRAINTS;
DROP TABLE samochody CASCADE CONSTRAINTS;
DROP TABLE klienci CASCADE CONSTRAINTS;
DROP TABLE akcesoria_cennik CASCADE CONSTRAINTS;
DROP TABLE klasy_samochodow CASCADE CONSTRAINTS;

DROP TYPE t_protokol FORCE;
DROP TYPE t_wypozyczenie FORCE;
DROP TYPE t_lista_wplat FORCE;
DROP TYPE t_lista_rozliczen FORCE;
DROP TYPE t_lista_akcesoriow FORCE;
DROP TYPE t_wplata FORCE;
DROP TYPE t_rozliczenie_pozycja FORCE;
DROP TYPE t_akcesorium_pozycja FORCE;
DROP TYPE t_samochod FORCE;
DROP TYPE t_kierowca_firmowy FORCE;
DROP TYPE t_klient_firm FORCE;
DROP TYPE t_klient_ind FORCE;
DROP TYPE t_podmiot FORCE;
DROP TYPE t_akcesorium_info FORCE;
DROP TYPE t_klasa_samochodu FORCE;
DROP TYPE t_adres FORCE;

COMMIT;

-- 2. Definicja Typów Obiektowych i Kolekcji

-- Typ ADRES
CREATE OR REPLACE TYPE t_adres AS OBJECT (
    miasto VARCHAR2(50),
    ulica VARCHAR2(50),
    nr_domu VARCHAR2(10),
    nr_lokalu VARCHAR2(10),
    kod_pocztowy VARCHAR2(10)
);
/

-- Typy Słownikowe
CREATE OR REPLACE TYPE t_klasa_samochodu AS OBJECT (
    id_klasy NUMBER,
    nazwa VARCHAR2(20),
    cena_za_dobe NUMBER(10,2),
    kaucja NUMBER(10,2),
    limit_km NUMBER(5),
    stawka_nad_km NUMBER(5,2),
    kara_paliwo NUMBER(10,2),
    doplata_zagranica NUMBER(10,2),
    cena_ubezp_std NUMBER(10,2),
    cena_ubezp_full NUMBER(10,2),
    
    MEMBER FUNCTION oblicz_koszt_bazowy(p_dni NUMBER) RETURN NUMBER
);
/

CREATE OR REPLACE TYPE t_akcesorium_info AS OBJECT (
    id_akcesorium NUMBER,
    nazwa VARCHAR2(50),
    cena_za_dobe NUMBER(10,2)
);
/

-- Hierarchia Podmiotów
CREATE OR REPLACE TYPE t_podmiot AS OBJECT (
    id_klienta NUMBER,
    email VARCHAR2(100),
    telefon VARCHAR2(20),
    czy_zablokowany NUMBER(1), -- 0: OK, 1: ZABLOKOWANY
    adres t_adres
) NOT FINAL NOT INSTANTIABLE;
/

CREATE OR REPLACE TYPE t_klient_ind UNDER t_podmiot (
    imie VARCHAR2(50),
    nazwisko VARCHAR2(50),
    pesel VARCHAR2(11),
    data_urodzenia DATE
);
/

CREATE OR REPLACE TYPE t_klient_firm UNDER t_podmiot (
    nazwa_firmy VARCHAR2(100),
    nip VARCHAR2(15)
);
/

-- Typ Kierowcy
CREATE OR REPLACE TYPE t_kierowca_firmowy AS OBJECT (
    id_kierowcy NUMBER,
    imie VARCHAR2(50),
    nazwisko VARCHAR2(50),
    pesel_lub_dowod VARCHAR2(20),
    nr_prawa_jazdy VARCHAR2(20),
    data_urodzenia DATE,
    ref_firma REF t_klient_firm
);
/

-- Typ Samochód
CREATE OR REPLACE TYPE t_samochod AS OBJECT (
    id_auta NUMBER,
    marka VARCHAR2(50),
    model VARCHAR2(50),
    nr_rejestracyjny VARCHAR2(20),
    vin VARCHAR2(17),
    aktualny_przebieg NUMBER(10),
    status_auta VARCHAR2(20), -- DOSTEPNY, WYPOZYCZONY, SERWIS, BRUDNY
    ref_klasa REF t_klasa_samochodu
);
/

-- Typy pomocnicze
CREATE OR REPLACE TYPE t_akcesorium_pozycja AS OBJECT (
    ref_akcesorium REF t_akcesorium_info,
    ilosc NUMBER,
    cena_w_dniu_wynajmu NUMBER(10,2)
);
/
CREATE OR REPLACE TYPE t_lista_akcesoriow AS TABLE OF t_akcesorium_pozycja;
/

CREATE OR REPLACE TYPE t_rozliczenie_pozycja AS OBJECT (
    typ_kosztu VARCHAR2(50),
    kwota NUMBER(10,2)
);
/

CREATE OR REPLACE TYPE t_lista_rozliczen AS TABLE OF t_rozliczenie_pozycja;
/

CREATE OR REPLACE TYPE t_wplata AS OBJECT (
    data_wplaty DATE,
    kwota NUMBER(10,2),
    metoda_platnosci VARCHAR2(20)
);
/

CREATE OR REPLACE TYPE t_lista_wplat AS TABLE OF t_wplata;
/

-- Główny Typ Transakcyjny
CREATE OR REPLACE TYPE t_wypozyczenie AS OBJECT (
    id_wypozyczenia NUMBER,
    data_od DATE,
    data_do_planowana DATE,
    data_zwrotu_faktyczna DATE,
    przebieg_start NUMBER(10),
    przebieg_koniec NUMBER(10),
    typ_ubezpieczenia VARCHAR2(10), -- BRAK, STD, FULL
    czy_wyjazd_zagranica VARCHAR2(1),
    status_realizacji VARCHAR2(20), -- REZERWACJA, W_TRAKCIE, ZWROCONY, ANULOWANA
    status_platnosci VARCHAR2(20),
    
    id_faktury_vat NUMBER,
    ref_auto REF t_samochod,
    ref_klient REF t_podmiot,
    ref_kierowca REF t_kierowca_firmowy,

    lista_akcesoriow t_lista_akcesoriow,
    lista_rozliczen t_lista_rozliczen,
    lista_wplat t_lista_wplat
);
/

-- Protokół
CREATE OR REPLACE TYPE t_protokol AS OBJECT (
    id_protokolu NUMBER,
    typ_protokolu VARCHAR2(20),
    opis_stanu VARCHAR2(200),
    czy_uszkodzony VARCHAR2(1),
    szacowany_koszt_naprawy NUMBER(10,2),
    ref_wypozyczenie REF t_wypozyczenie
);
/

-- Dodajemy tabelę kontraktów
CREATE TABLE kontrakty (
    id_kontraktu NUMBER PRIMARY KEY,
    ref_firma REF t_klient_firm,
    data_waznosci DATE,
    rabat_kontraktowy NUMBER(5,2),
    limit_kredytowy NUMBER(10,2)
);

-- Dodajemy tabelę faktur zbiorczych
CREATE TABLE faktury_vat (
    id_faktury NUMBER PRIMARY KEY,
    nr_faktury VARCHAR2(50),
    data_wystawienia DATE,
    kwota_brutto NUMBER(10,2),
    ref_firma REF t_klient_firm,
    status VARCHAR2(20)
);

-- 3. Tworzenie Tabel Obiektowych

CREATE TABLE klasy_samochodow OF t_klasa_samochodu (id_klasy PRIMARY KEY);
CREATE TABLE akcesoria_cennik OF t_akcesorium_info (id_akcesorium PRIMARY KEY);
CREATE OR REPLACE TYPE t_lista_ids AS TABLE OF NUMBER;
/

CREATE TABLE klienci OF t_podmiot (id_klienta PRIMARY KEY);

CREATE TABLE kierowcy_firmowi OF t_kierowca_firmowy (id_kierowcy PRIMARY KEY);

CREATE TABLE samochody OF t_samochod (id_auta PRIMARY KEY);

CREATE TABLE wypozyczenia OF t_wypozyczenie (id_wypozyczenia PRIMARY KEY)
NESTED TABLE lista_akcesoriow STORE AS nt_akcesoria,
NESTED TABLE lista_rozliczen STORE AS nt_rozliczenia,
NESTED TABLE lista_wplat STORE AS nt_wplaty;


CREATE TABLE protokoly_uszkodzen OF t_protokol (id_protokolu PRIMARY KEY);

-- 4. Metody

CREATE OR REPLACE TYPE BODY t_klasa_samochodu AS
    MEMBER FUNCTION oblicz_koszt_bazowy(p_dni NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN self.cena_za_dobe * p_dni;
    END;
END;
/

-- 5. Pakiety i Logika Biznesowa

-- Sekwencja
CREATE SEQUENCE seq_wypozyczenia START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_faktury START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_kontrakty START WITH 1 INCREMENT BY 1;

-- PKG_WYNAJEM
//////////////////// / / / / / / ////// / /////
CREATE OR REPLACE PACKAGE pkg_wynajem AS
    PROCEDURE utworz_klienta(p_id NUMBER, p_imie VARCHAR2, p_nazwisko VARCHAR2, p_pesel VARCHAR2, p_data_uro DATE, p_adres t_adres);
    PROCEDURE utworz_klienta(p_id NUMBER, p_nazwa_firmy VARCHAR2, p_nip VARCHAR2, p_adres t_adres);
    
    PROCEDURE utworz_rezerwacje(
        p_id_klienta NUMBER, 
        p_id_auta NUMBER, 
        p_data_od DATE, 
        p_dni NUMBER, 
        p_ubezp VARCHAR2, 
        p_zagranica VARCHAR2,
        p_id_kierowcy NUMBER DEFAULT NULL,
        p_akcesoria_ids t_lista_ids DEFAULT NULL
    );
    
    PROCEDURE anuluj_rezerwacje(p_id_wyp NUMBER);
    PROCEDURE przedluz_najem(p_id_wyp NUMBER, p_nowa_data_do DATE);
    PROCEDURE wydaj_samochod(p_id_wyp NUMBER);
    PROCEDURE zaksieguj_wplate(p_id_wyp NUMBER, p_kwota NUMBER, p_metoda VARCHAR2);
END pkg_wynajem;
/

CREATE OR REPLACE PACKAGE BODY pkg_wynajem AS

    PROCEDURE utworz_klienta(p_id NUMBER, p_imie VARCHAR2, p_nazwisko VARCHAR2, p_pesel VARCHAR2, p_data_uro DATE, p_adres t_adres) IS
    BEGIN
        INSERT INTO klienci VALUES (
            t_klient_ind(p_id, NULL, NULL, 0, p_adres, p_imie, p_nazwisko, p_pesel, p_data_uro)
        );
    END;

    PROCEDURE utworz_klienta(p_id NUMBER, p_nazwa_firmy VARCHAR2, p_nip VARCHAR2, p_adres t_adres) IS
    BEGIN
        INSERT INTO klienci VALUES (
            t_klient_firm(p_id, NULL, NULL, 0, p_adres, p_nazwa_firmy, p_nip)
        );
    END;

    PROCEDURE utworz_rezerwacje(p_id_klienta NUMBER, p_id_auta NUMBER, p_data_od DATE, p_dni NUMBER, p_ubezp VARCHAR2, p_zagranica VARCHAR2, p_id_kierowcy NUMBER DEFAULT NULL, p_akcesoria_ids t_lista_ids DEFAULT NULL) IS
        v_ref_klient REF t_podmiot;
        v_ref_auto REF t_samochod;
        v_ref_kierowca REF t_kierowca_firmowy := NULL;
        v_klasa t_klasa_samochodu;
        v_akcesoria t_lista_akcesoriow := t_lista_akcesoriow();
        v_rozliczenia t_lista_rozliczen := t_lista_rozliczen();
        v_koszt_total NUMBER := 0;
        v_temp_koszt NUMBER := 0;
        v_klient_obj t_podmiot;
        
        v_kolizja NUMBER;
        v_data_do_krezerwaci DATE;
        v_kwota_rabatu NUMBER := 0;
        v_rabat_kontraktowy NUMBER := 0;
        v_liczba_aut_firmy NUMBER := 0;
        v_status_platnosci_start VARCHAR2(20) := 'NIEOPLACONE';
    
    BEGIN
        v_data_do_krezerwaci := p_data_od + p_dni;
        
        SELECT REF(k), VALUE(k) INTO v_ref_klient, v_klient_obj FROM klienci k WHERE id_klienta = p_id_klienta;
        SELECT REF(s) INTO v_ref_auto FROM samochody s WHERE id_auta = p_id_auta;
        SELECT DEREF(DEREF(v_ref_auto).ref_klasa) INTO v_klasa FROM DUAL;
        
        IF v_klient_obj.czy_zablokowany = 1 THEN
            RAISE_APPLICATION_ERROR(-20106, 'Błąd: Klient jest zablokowany!');
        END IF;
        
        SELECT COUNT(*) INTO v_kolizja
        FROM wypozyczenia w
        WHERE DEREF(w.ref_auto).id_auta = p_id_auta
          AND w.status_realizacji IN ('REZERWACJA', 'W_TRAKCIE') -- Ignorujemy anulowane i zwrócone
          AND w.data_od < v_data_do_krezerwaci      -- Istniejący start < Nowy koniec
          AND w.data_do_planowana > p_data_od;   -- Istniejący koniec > Nowy start

        IF v_kolizja > 0 THEN
            RAISE_APPLICATION_ERROR(-20102, 'Auto zajęte!');
        END IF;
        
        -- FIRMA
        IF v_klient_obj IS OF (t_klient_firm) THEN
            IF p_id_kierowcy IS NULL THEN
                RAISE_APPLICATION_ERROR(-20200, 'Dla Firm wymagane jest wskazanie Kierowcy (Pracownika).');
            END IF;
            -- Pobieramy ref do kierowcy
            SELECT REF(k) INTO v_ref_kierowca FROM kierowcy_firmowi k WHERE id_kierowcy = p_id_kierowcy;
            
            -- SPRAWDZENIE KONTRAKTU (B2B)
            BEGIN
                SELECT rabat_kontraktowy INTO v_rabat_kontraktowy 
                FROM kontrakty k 
                WHERE k.ref_firma.id_klienta = p_id_klienta AND k.data_waznosci >= SYSDATE;
                
                DBMS_OUTPUT.PUT_LINE('Znaleziono aktywny kontrakt! Rabat: ' || (v_rabat_kontraktowy*100) || '%');
                v_status_platnosci_start := 'ODROCZONE_B2B'; -- Ustawiamy specyficzny status
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    v_rabat_kontraktowy := 0;
            END;
        END IF;
        
        -- KOSZT BAZOWY AUTA
        v_temp_koszt := v_klasa.cena_za_dobe * p_dni;
        
        IF v_rabat_kontraktowy > 0 THEN
             v_temp_koszt := v_temp_koszt * (1 - v_rabat_kontraktowy);
             DBMS_OUTPUT.PUT_LINE('Cena po rabacie kontraktowym: ' || v_temp_koszt);
        END IF;
        
        v_rozliczenia.EXTEND;
        v_rozliczenia(v_rozliczenia.LAST) := t_rozliczenie_pozycja('WYNAJEM_AUTO', v_temp_koszt);
        v_koszt_total := v_koszt_total + v_temp_koszt;

        IF v_status_platnosci_start = 'ODROCZONE_B2B' THEN
             DBMS_OUTPUT.PUT_LINE('Klient korporacyjny - brak pobierania kaucji.');
        ELSE
             v_rozliczenia.EXTEND;
             v_rozliczenia(v_rozliczenia.LAST) := t_rozliczenie_pozycja('KAUCJA_ZWROTNA', v_klasa.kaucja);
             v_koszt_total := v_koszt_total + v_klasa.kaucja;
        END IF;
        
        -- RABATY ---
        IF v_klient_obj IS OF (t_klient_ind) AND p_dni > 3 THEN
            v_kwota_rabatu := v_temp_koszt * 0.10;
            
            v_rozliczenia.EXTEND;
            v_rozliczenia(v_rozliczenia.LAST) := t_rozliczenie_pozycja('RABAT_INDYWIDUALNY (-10%)', -v_kwota_rabatu);
            
            v_koszt_total := v_koszt_total - v_kwota_rabatu;
            
            DBMS_OUTPUT.PUT_LINE('Naliczono rabat: ' || v_kwota_rabatu || ' PLN');
        END IF;

        -- 2. KAUCJA (zawsze dodawana do rozliczenia startowego)
        v_rozliczenia.EXTEND;
        v_rozliczenia(v_rozliczenia.LAST) := t_rozliczenie_pozycja('KAUCJA_ZWROTNA', v_klasa.kaucja);
        v_koszt_total := v_koszt_total + v_klasa.kaucja;

        -- 3. UBEZPIECZENIE
        v_temp_koszt := CASE p_ubezp 
            WHEN 'STD' THEN v_klasa.cena_ubezp_std * p_dni
            WHEN 'FULL' THEN v_klasa.cena_ubezp_full * p_dni
            ELSE 0 END;
        
        IF v_temp_koszt > 0 THEN
            v_rozliczenia.EXTEND;
            v_rozliczenia(v_rozliczenia.LAST) := t_rozliczenie_pozycja('UBEZPIECZENIE_'||p_ubezp, v_temp_koszt);
            v_koszt_total := v_koszt_total + v_temp_koszt;
        END IF;

        -- 4. OBSŁUGA AKCESORIÓW
        IF p_akcesoria_ids IS NOT NULL THEN
            FOR i IN 1..p_akcesoria_ids.COUNT LOOP
                FOR rec IN (SELECT REF(a) as r, cena_za_dobe, nazwa 
                FROM akcesoria_cennik a
                WHERE id_akcesorium = p_akcesoria_ids(i)) 
                LOOP
                    -- Dodanie do listy obiektów akcesoriów
                    v_akcesoria.EXTEND;
                    v_akcesoria(v_akcesoria.LAST) := t_akcesorium_pozycja(rec.r, 1, rec.cena_za_dobe);
                    
                    -- Dodanie kosztu akcesorium do rozliczenia
                    v_temp_koszt := rec.cena_za_dobe * p_dni;
                    v_rozliczenia.EXTEND;
                    v_rozliczenia(v_rozliczenia.LAST) := t_rozliczenie_pozycja('AKCESORIUM_'||rec.nazwa, v_temp_koszt);
                    v_koszt_total := v_koszt_total + v_temp_koszt;
                END LOOP;
            END LOOP;
        END IF;

        INSERT INTO wypozyczenia VALUES (
            t_wypozyczenie(
                seq_wypozyczenia.NEXTVAL,
                p_data_od,
                v_data_do_krezerwaci,
                NULL, 
                0,
                0,
                p_ubezp,
                p_zagranica,
                'REZERWACJA',
                v_status_platnosci_start,
                NULL,
                v_ref_auto, v_ref_klient, v_ref_kierowca,
                v_akcesoria, v_rozliczenia, t_lista_wplat()
            )
        );
        DBMS_OUTPUT.PUT_LINE('Rezerwacja OK. Razem do zapłaty (z kaucją): ' || v_koszt_total || ' PLN');
    END;

    PROCEDURE anuluj_rezerwacje(p_id_wyp NUMBER) IS
        v_status VARCHAR2(20);
    BEGIN
        SELECT status_realizacji INTO v_status FROM wypozyczenia WHERE id_wypozyczenia = p_id_wyp;
        
        IF v_status <> 'REZERWACJA' THEN
             RAISE_APPLICATION_ERROR(-20000, 'Można anulować tylko rezerwacje.');
        END IF;

        UPDATE wypozyczenia 
        SET status_realizacji = 'ANULOWANA'
        WHERE id_wypozyczenia = p_id_wyp;
    END;

    PROCEDURE przedluz_najem(p_id_wyp NUMBER, p_nowa_data_do DATE) IS
        v_id_auta NUMBER;
        v_cnt NUMBER;
        v_data_do_obecna DATE;
    BEGIN
        SELECT DEREF(ref_auto).id_auta, data_do_planowana 
        INTO v_id_auta, v_data_do_obecna
        FROM wypozyczenia 
        WHERE id_wypozyczenia = p_id_wyp;

        IF p_nowa_data_do <= v_data_do_obecna THEN
            RAISE_APPLICATION_ERROR(-20001, 'Nowa data musi być późniejsza niż obecna.');
        END IF;

        SELECT COUNT(*) INTO v_cnt FROM wypozyczenia w
        WHERE DEREF(w.ref_auto).id_auta = v_id_auta
          AND w.id_wypozyczenia <> p_id_wyp
          AND w.status_realizacji IN ('REZERWACJA', 'W_TRAKCIE')
          AND w.data_od < p_nowa_data_do 
          AND w.data_do_planowana > v_data_do_obecna;

        IF v_cnt > 0 THEN
             RAISE_APPLICATION_ERROR(-20102, 'Nie można przedłużyć - auto jest zarezerwowane w tym terminie.');
        END IF;

        UPDATE wypozyczenia 
        SET data_do_planowana = p_nowa_data_do
        WHERE id_wypozyczenia = p_id_wyp;
        
        DBMS_OUTPUT.PUT_LINE('Przedłużono najem do: ' || p_nowa_data_do);
    END;

    PROCEDURE wydaj_samochod(p_id_wyp NUMBER) IS
        v_status_platnosci VARCHAR2(20);
        v_ref_auto REF t_samochod;
        v_przebieg NUMBER;
    BEGIN
        SELECT status_platnosci, ref_auto INTO v_status_platnosci, v_ref_auto 
        FROM wypozyczenia WHERE id_wypozyczenia = p_id_wyp;

        IF v_status_platnosci = 'NIEOPLACONE' THEN
            RAISE_APPLICATION_ERROR(-20103, 'Brak opłaty! Nie można wydać auta.');
        ELSIF v_status_platnosci = 'ODROCZONE_B2B' THEN
            DBMS_OUTPUT.PUT_LINE('Weryfikacja Firmowa OK. Odpowiedzialność finansowa przeniesiona na Firmę.');
        END IF;

        SELECT DEREF(v_ref_auto).aktualny_przebieg INTO v_przebieg FROM DUAL;

        UPDATE wypozyczenia 
        SET status_realizacji = 'W_TRAKCIE', przebieg_start = v_przebieg
        WHERE id_wypozyczenia = p_id_wyp;
        
        UPDATE samochody s SET status_auta = 'WYPOZYCZONY' WHERE REF(s) = v_ref_auto;
    END;

    PROCEDURE zaksieguj_wplate(p_id_wyp NUMBER, p_kwota NUMBER, p_metoda VARCHAR2) IS
       v_wymagane NUMBER;
    BEGIN
        -- Obliczamy sumę z tabeli zagnieżdżonej rozliczeń dla danego wynajmu
        SELECT SUM(kwota) INTO v_wymagane 
        FROM TABLE(SELECT lista_rozliczen FROM wypozyczenia WHERE id_wypozyczenia = p_id_wyp);

        IF p_kwota < v_wymagane THEN
            RAISE_APPLICATION_ERROR(-20105, 'Błąd: Wpłacono '||p_kwota||', a wymagane jest min. '||v_wymagane);
        END IF;

        INSERT INTO TABLE(SELECT lista_wplat FROM wypozyczenia WHERE id_wypozyczenia = p_id_wyp)
        VALUES (t_wplata(SYSDATE, p_kwota, p_metoda));

        UPDATE wypozyczenia SET status_platnosci = 'OPLACONE' WHERE id_wypozyczenia = p_id_wyp;
    END;
END pkg_wynajem;
/

CREATE OR REPLACE VIEW v_raport_wynajmow AS
SELECT 
    w.id_wypozyczenia as ID,
    DEREF(w.ref_klient).email as KLIENT,
    DEREF(w.ref_auto).marka || ' ' || DEREF(w.ref_auto).model as AUTO,
    w.data_od as OD,
    w.data_do_planowana as DO,
    (SELECT SUM(kwota) FROM TABLE(w.lista_rozliczen)) as KOSZT_CALKOWITY,
    (SELECT SUM(kwota) FROM TABLE(w.lista_wplat)) as WPLACONO,
    w.status_platnosci as STATUS
FROM wypozyczenia w;
/

-- PKG_ZWROTY

CREATE OR REPLACE PACKAGE pkg_zwroty AS
    PROCEDURE przetworz_zwrot(p_id_wyp NUMBER, p_przebieg_koniec NUMBER, p_stan_paliwa NUMBER, p_czy_uszkodzenia VARCHAR2);
    PROCEDURE przywroc_do_floty(p_id_auta NUMBER);
END pkg_zwroty;
/

CREATE OR REPLACE PACKAGE BODY pkg_zwroty AS
    PROCEDURE przetworz_zwrot(p_id_wyp NUMBER, p_przebieg_koniec NUMBER, p_stan_paliwa NUMBER, p_czy_uszkodzenia VARCHAR2) IS
        v_ref_auto REF t_samochod;
        v_klasa t_klasa_samochodu;
        v_typ_ubezp VARCHAR2(20);
        v_status_platnosci VARCHAR2(20);
        
        v_data_od DATE;
        v_przebieg_start NUMBER;
        v_dni_wynajmu NUMBER;
        v_dystans_faktyczny NUMBER;
        v_limit_total NUMBER;
        v_nadprzebieg NUMBER;
        v_kara_km NUMBER := 0;
        
        v_kara_paliwo NUMBER := 0;
        v_potracenie_kaucji NUMBER := 0;
        v_nowy_status_auta VARCHAR2(20);
    BEGIN
        SELECT typ_ubezpieczenia, data_od, przebieg_start, status_platnosci 
        INTO v_typ_ubezp, v_data_od, v_przebieg_start, v_status_platnosci 
        FROM wypozyczenia 
        WHERE id_wypozyczenia = p_id_wyp;

        IF p_czy_uszkodzenia = 'T' THEN
            v_nowy_status_auta := 'SERWIS';
            DBMS_OUTPUT.PUT_LINE('Auto zgłoszone jako USZKODZONE. Skierowano do: SERWIS.');
        ELSE
            v_nowy_status_auta := 'BRUDNY';
            DBMS_OUTPUT.PUT_LINE('Auto zwrócone sprawne. Skierowano do: MYJNIA (Status: BRUDNY).');
        END IF;

        UPDATE wypozyczenia
        SET data_zwrotu_faktyczna = SYSDATE,
            przebieg_koniec = p_przebieg_koniec,
            status_realizacji = 'ZWROCONY'
        WHERE id_wypozyczenia = p_id_wyp
        RETURNING ref_auto INTO v_ref_auto;

        SELECT DEREF(DEREF(v_ref_auto).ref_klasa) INTO v_klasa FROM DUAL;

        v_dni_wynajmu := CEIL(SYSDATE - v_data_od);
        IF v_dni_wynajmu < 1 THEN v_dni_wynajmu := 1; END IF;

        -- Obliczamy dystans i limity
        v_dystans_faktyczny := p_przebieg_koniec - v_przebieg_start;
        v_limit_total := v_klasa.limit_km * v_dni_wynajmu; -- Limit dzienny * dni

        DBMS_OUTPUT.PUT_LINE('--- ROZLICZENIE PRZEBIEGU ---');
        DBMS_OUTPUT.PUT_LINE('Dni: ' || v_dni_wynajmu || ' | Przejechano: ' || v_dystans_faktyczny || ' km | Limit: ' || v_limit_total || ' km');

        -- Sprawdzamy czy przekroczono limit
        IF v_dystans_faktyczny > v_limit_total THEN
            v_nadprzebieg := v_dystans_faktyczny - v_limit_total;
            v_kara_km := v_nadprzebieg * v_klasa.stawka_nad_km;
            
            INSERT INTO TABLE(
                SELECT lista_rozliczen 
                FROM wypozyczenia 
                WHERE id_wypozyczenia = p_id_wyp)
            VALUES (t_rozliczenie_pozycja('KARA_LIMIT_KM (' || v_nadprzebieg || ' km)', v_kara_km));
            
            DBMS_OUTPUT.PUT_LINE('PRZEKROCZENIE LIMITU! Dopłata: ' || v_kara_km || ' PLN (' || v_nadprzebieg || ' km * ' || v_klasa.stawka_nad_km || ' zł)');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Limit kilometrów zachowany.');
        END IF;


        IF p_czy_uszkodzenia = 'T' THEN
            IF v_typ_ubezp = 'FULL' THEN
                v_potracenie_kaucji := 0;
                DBMS_OUTPUT.PUT_LINE('Uszkodzenie (FULL): Brak potrąceń z kaucji.');
                
            ELSIF v_typ_ubezp = 'STD' THEN
                v_potracenie_kaucji := v_klasa.kaucja * 0.5;
                DBMS_OUTPUT.PUT_LINE('Uszkodzenie (STD): Potrącenie 50% kaucji (' || v_potracenie_kaucji || ' PLN).');
                
            ELSE
                v_potracenie_kaucji := v_klasa.kaucja;
                DBMS_OUTPUT.PUT_LINE('Uszkodzenie (BRAK UBEZP): Potrącenie 100% kaucji (' || v_potracenie_kaucji || ' PLN).');
            END IF;

            IF v_potracenie_kaucji > 0 THEN
                INSERT INTO TABLE(SELECT lista_rozliczen FROM wypozyczenia WHERE id_wypozyczenia = p_id_wyp)
                VALUES (t_rozliczenie_pozycja('POTRACENIE_KAUCJI_SZKODA', v_potracenie_kaucji));
            END IF;
        END IF;

        IF p_stan_paliwa < 100 THEN
             v_kara_paliwo := v_klasa.kara_paliwo;
             INSERT INTO TABLE(SELECT lista_rozliczen FROM wypozyczenia WHERE id_wypozyczenia = p_id_wyp)
             VALUES (t_rozliczenie_pozycja('KARA_PALIWO', v_kara_paliwo));
        END IF;

        UPDATE samochody s SET status_auta = v_nowy_status_auta, aktualny_przebieg = p_przebieg_koniec 
        WHERE REF(s) = v_ref_auto;
        
        IF v_status_platnosci = 'ODROCZONE_B2B' THEN
             UPDATE wypozyczenia SET status_platnosci = 'DO_FAKTUROWANIA' WHERE id_wypozyczenia = p_id_wyp;
             DBMS_OUTPUT.PUT_LINE('Status płatności: DO_FAKTUROWANIA (Koszty trafią na fakturę zbiorczą).');
        ELSE
             UPDATE wypozyczenia SET status_platnosci = 'DO_ROZLICZENIA' WHERE id_wypozyczenia = p_id_wyp;
             DBMS_OUTPUT.PUT_LINE('Status płatności: DO_ROZLICZENIA (Wymagana dopłata przy ladzie).');
        END IF;
    END;

    PROCEDURE przywroc_do_floty(p_id_auta NUMBER) IS
    BEGIN
        UPDATE samochody
        SET status_auta = 'DOSTEPNY'
        WHERE id_auta = p_id_auta
          AND status_auta IN ('SERWIS', 'BRUDNY', 'ZWROCONY');
          
        IF SQL%ROWCOUNT = 0 THEN
             DBMS_OUTPUT.PUT_LINE('Auto nie wymaga przywrócenia lub nie istnieje.');
        ELSE
             DBMS_OUTPUT.PUT_LINE('Auto ' || p_id_auta || ' jest ponownie DOSTĘPNE.');
        END IF;
    END;

END pkg_zwroty;
/


CREATE OR REPLACE PROCEDURE generuj_fakture_zbiorcza(p_id_firmy NUMBER) IS
    v_suma_netto NUMBER := 0;
    v_nowe_id_faktury NUMBER;
    v_ref_firmy REF t_klient_firm;
    v_cnt NUMBER := 0;
BEGIN
    SELECT TREAT(REF(k) AS REF t_klient_firm) 
    INTO v_ref_firmy 
    FROM klienci k 
    WHERE id_klienta = p_id_firmy;
    
    -- 1. Obliczamy sumę kosztów
    FOR r IN (
        SELECT w.id_wypozyczenia, 
               (SELECT SUM(kwota) FROM TABLE(w.lista_rozliczen)) as suma_wyp
        FROM wypozyczenia w
        -- POPRAWKA 2: Użycie DEREF do dobrania się do ID klienta wewnątrz referencji
        WHERE DEREF(w.ref_klient).id_klienta = p_id_firmy
          AND w.status_platnosci = 'DO_FAKTUROWANIA'
    ) LOOP
        v_suma_netto := v_suma_netto + r.suma_wyp;
        v_cnt := v_cnt + 1;
    END LOOP;

    IF v_cnt = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Brak wypożyczeń do zafakturowania dla firmy ' || p_id_firmy);
        RETURN;
    END IF;

    -- 2. Generujemy fakturę
    v_nowe_id_faktury := seq_faktury.NEXTVAL;
    
    INSERT INTO faktury_vat VALUES (
        v_nowe_id_faktury, 
        'FV/' || TO_CHAR(SYSDATE, 'YYYY/MM/') || v_nowe_id_faktury,
        SYSDATE,
        v_suma_netto,
        v_ref_firmy,
        'NIEOPLACONA'
    );

    -- 3. Oznaczamy wypożyczenia
    UPDATE wypozyczenia w
    SET id_faktury_vat = v_nowe_id_faktury,
        status_platnosci = 'ZAKONCZONE'
    -- POPRAWKA 3: Tutaj również DEREF w klauzuli WHERE
    WHERE DEREF(w.ref_klient).id_klienta = p_id_firmy
      AND status_platnosci = 'DO_FAKTUROWANIA';

    DBMS_OUTPUT.PUT_LINE('Wygenerowano Fakturę Zbiorczą nr ' || 'FV/' || TO_CHAR(SYSDATE, 'YYYY/MM/') || v_nowe_id_faktury);
    DBMS_OUTPUT.PUT_LINE('Liczba pozycji: ' || v_cnt || ', Łączna kwota: ' || v_suma_netto || ' PLN');
END;
/


-- PKG_RAPORTY

CREATE OR REPLACE PACKAGE pkg_raporty AS
    FUNCTION pobierz_historie_klienta(p_id_klienta NUMBER) RETURN SYS_REFCURSOR;
END pkg_raporty;
/

CREATE OR REPLACE PACKAGE BODY pkg_raporty AS
    FUNCTION pobierz_historie_klienta(p_id_klienta NUMBER) RETURN SYS_REFCURSOR IS
        v_kursor SYS_REFCURSOR;
    BEGIN
        OPEN v_kursor FOR
            SELECT w.data_od, 
                   DEREF(w.ref_auto).marka AS auto, 
                   w.status_realizacji,
                   w.status_platnosci
            FROM wypozyczenia w
            WHERE w.ref_klient.id_klienta = p_id_klienta;
        RETURN v_kursor;
    END;
END pkg_raporty;
/

-- Wyzwalacze

CREATE OR REPLACE TRIGGER trg_check_wiek
BEFORE INSERT ON wypozyczenia
FOR EACH ROW
DECLARE
    v_klient_ind t_klient_ind;
    v_is_ind BOOLEAN := FALSE;
BEGIN
    BEGIN
        SELECT TREAT(DEREF(:NEW.ref_klient) AS t_klient_ind) INTO v_klient_ind FROM DUAL;
        IF v_klient_ind IS NOT NULL THEN
            v_is_ind := TRUE;
        END IF;
    EXCEPTION 
        WHEN OTHERS THEN v_is_ind := FALSE;
    END;

    IF v_is_ind THEN
        IF MONTHS_BETWEEN(SYSDATE, v_klient_ind.data_urodzenia)/12 < 21 THEN
             RAISE_APPLICATION_ERROR(-20101, 'Klient indywidualny musi mieć min. 21 lat.');
        END IF;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_auto_przebieg
BEFORE UPDATE ON wypozyczenia
FOR EACH ROW
BEGIN
    IF :NEW.przebieg_koniec IS NOT NULL AND :NEW.przebieg_koniec < :OLD.przebieg_start THEN
         RAISE_APPLICATION_ERROR(-20104, 'Przebieg końcowy mniejszy niż początkowy!');
    END IF;
END;
/


-- 6. Dane testowe

-- Dodanie klas samochodów

INSERT INTO klasy_samochodow VALUES (t_klasa_samochodu(1, 'KLASA A', 100, 300, 200, 1.0, 50, 100, 30, 60));
INSERT INTO klasy_samochodow VALUES (t_klasa_samochodu(2, 'KLASA B', 130, 500, 300, 1.5, 60, 150, 40, 80));
INSERT INTO klasy_samochodow VALUES (t_klasa_samochodu(3, 'KLASA C', 150, 700, 400, 2.0, 70, 170, 50, 100));
INSERT INTO klasy_samochodow VALUES (t_klasa_samochodu(4, 'SUV', 200, 2000, 800, 2.0, 80, 180, 60, 150));
INSERT INTO klasy_samochodow VALUES (t_klasa_samochodu(5, 'DOSTAWCZE', 230, 1200, 700, 3.0, 100, 250, 70, 180));
INSERT INTO klasy_samochodow VALUES (t_klasa_samochodu(6, 'PREMIUM', 300, 3000, 200, 5.0, 150, 400, 100, 300));
COMMIT;

-- Dodanie samochodów do danej klasy

-- KLASA A
INSERT INTO samochody VALUES (t_samochod(201, 'Volkswagen', 'Polo', 'WA201', 'VIN201A', 45000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=1)));
INSERT INTO samochody VALUES (t_samochod(202, 'Volkswagen', 'Polo', 'WA202', 'VIN202A', 48200, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=1)));
INSERT INTO samochody VALUES (t_samochod(203, 'Volkswagen', 'Polo', 'WA203', 'VIN203A', 51000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=1)));
INSERT INTO samochody VALUES (t_samochod(204, 'Volkswagen', 'Polo', 'WA204', 'VIN204A', 12000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=1)));
INSERT INTO samochody VALUES (t_samochod(205, 'Volkswagen', 'Polo', 'WA205', 'VIN205A', 36500, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=1)));

-- KLASA B
INSERT INTO samochody VALUES (t_samochod(206, 'Toyota', 'Corolla', 'WA206', 'VIN206B', 60000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=2)));
INSERT INTO samochody VALUES (t_samochod(207, 'Toyota', 'Corolla', 'WA207', 'VIN207B', 25000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=2)));
INSERT INTO samochody VALUES (t_samochod(208, 'Toyota', 'Corolla', 'WA208', 'VIN208B', 33000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=2)));
INSERT INTO samochody VALUES (t_samochod(209, 'Toyota', 'Corolla', 'WA209', 'VIN209B', 15000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=2)));
INSERT INTO samochody VALUES (t_samochod(210, 'Toyota', 'Corolla', 'WA210', 'VIN210B', 41000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=2)));

-- KLASA C
INSERT INTO samochody VALUES (t_samochod(211, 'Volkswagen', 'Passat Kombi', 'WA211', 'VIN211C', 80000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=3)));
INSERT INTO samochody VALUES (t_samochod(212, 'Volkswagen', 'Passat Kombi', 'WA212', 'VIN212C', 75000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=3)));
INSERT INTO samochody VALUES (t_samochod(213, 'Volkswagen', 'Passat Kombi', 'WA213', 'VIN213C', 90000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=3)));
INSERT INTO samochody VALUES (t_samochod(214, 'Volkswagen', 'Passat Kombi', 'WA214', 'VIN214C', 62000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=3)));
INSERT INTO samochody VALUES (t_samochod(215, 'Volkswagen', 'Passat Kombi', 'WA215', 'VIN215C', 54000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=3)));

-- KLASA SUV
INSERT INTO samochody VALUES (t_samochod(216, 'Hyundai', 'Tucson', 'WA216', 'VIN216S', 30000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=4)));
INSERT INTO samochody VALUES (t_samochod(217, 'Hyundai', 'Tucson', 'WA217', 'VIN217S', 28000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=4)));
INSERT INTO samochody VALUES (t_samochod(218, 'Hyundai', 'Tucson', 'WA218', 'VIN218S', 35000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=4)));
INSERT INTO samochody VALUES (t_samochod(219, 'Hyundai', 'Tucson', 'WA219', 'VIN219S', 15000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=4)));
INSERT INTO samochody VALUES (t_samochod(220, 'Hyundai', 'Tucson', 'WA220', 'VIN220S', 40000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=4)));

-- KLASA DOSTAWCZE
INSERT INTO samochody VALUES (t_samochod(221, 'Renault', 'Master', 'WA221', 'VIN221D', 120000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=5)));
INSERT INTO samochody VALUES (t_samochod(222, 'Renault', 'Master', 'WA222', 'VIN222D', 110000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=5)));
INSERT INTO samochody VALUES (t_samochod(223, 'Renault', 'Master', 'WA223', 'VIN223D', 135000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=5)));
INSERT INTO samochody VALUES (t_samochod(224, 'Renault', 'Master', 'WA224', 'VIN224D', 95000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=5)));
INSERT INTO samochody VALUES (t_samochod(225, 'Renault', 'Master', 'WA225', 'VIN225D', 105000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=5)));

-- KLASA PREMIUM
INSERT INTO samochody VALUES (t_samochod(226, 'BMW', 'Seria 5', 'WA226', 'VIN226P', 20000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=6)));
INSERT INTO samochody VALUES (t_samochod(227, 'BMW', 'Seria 5', 'WA227', 'VIN227P', 15000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=6)));
INSERT INTO samochody VALUES (t_samochod(228, 'BMW', 'Seria 5', 'WA228', 'VIN228P', 25000, 'DOSTEPNY', (SELECT REF(k) FROM klasy_samochodow k WHERE id_klasy=6)));

-- Dodanie akcesorii
INSERT INTO akcesoria_cennik VALUES (t_akcesorium_info(1, 'Foteliki dziecięcy', 20));
INSERT INTO akcesoria_cennik VALUES (t_akcesorium_info(2, 'Nawigacja GPS', 15));
INSERT INTO akcesoria_cennik VALUES (t_akcesorium_info(3, 'Łańcuchy na koła', 10));
INSERT INTO akcesoria_cennik VALUES (t_akcesorium_info(4, 'Bagażnik dachowy', 30));

COMMIT;

-- Klienci indywidualni

INSERT INTO klienci VALUES (
    t_klient_ind(1, 'jan.kowalski@wp.pl', '500100100', 0,
    t_adres('Warszawa', 'Marszałkowska', '10', '1', '00-001'), 
    'Jan', 'Kowalski', '90010112345', TO_DATE('1990-01-01', 'YYYY-MM-DD'))
);

INSERT INTO klienci VALUES (
    t_klient_ind(2, 'anna.nowak@gmail.com', '600200200', 0,
    t_adres('Kraków', 'Floriańska', '5', '12', '31-002'), 
    'Anna', 'Nowak', '95050554321', TO_DATE('1995-05-05', 'YYYY-MM-DD'))
);

INSERT INTO klienci VALUES (
    t_klient_ind(3, 'piotr.wisniewski@onet.pl', '700300300', 0,
    t_adres('Gdańsk', 'Długa', '44', '', '80-003'), 
    'Piotr', 'Wiśniewski', '85031599887', TO_DATE('1985-03-15', 'YYYY-MM-DD'))
);

INSERT INTO klienci VALUES (
    t_klient_ind(4, 'maria.lewandowska@interia.pl', '800400400', 0,
    t_adres('Poznań', 'Półwiejska', '2', '5', '61-004'), 
    'Maria', 'Lewandowska', '00221200000', TO_DATE('2000-02-12', 'YYYY-MM-DD'))
);
COMMIT;

-- Klienci firmowi

INSERT INTO klienci VALUES (
    t_klient_firm(5, 'biuro@budimex.pl', '221111111', 0,
    t_adres('Warszawa', 'Stawki', '40', '', '01-040'), 
    'Budimex SA', '5260000001')
);

INSERT INTO klienci VALUES (
    t_klient_firm(6, 'contact@comarch.com', '122222222', 0,
    t_adres('Kraków', 'Życzkowskiego', '23', '', '31-864'), 
    'Comarch SA', '6770000002')
);

INSERT INTO klienci VALUES (
    t_klient_firm(7, 'info@orlen.pl', '243333333', 0,
    t_adres('Płock', 'Chemików', '7', '', '09-411'), 
    'PKN Orlen', '7740000003')
);

INSERT INTO klienci VALUES (
    t_klient_firm(8, 'poczta@cdprojekt.pl', '224444444', 0,
    t_adres('Warszawa', 'Jagiellońska', '74', '', '03-301'), 
    'CD Projekt', '7320000004')
);
COMMIT;

-- Kierowcy firmowi

-- Kierowca dla Budimex
INSERT INTO kierowcy_firmowi VALUES (
    t_kierowca_firmowy(1, 'Adam', 'Małysz', 'DO12345', 'PJ001', TO_DATE('1980-05-20','YYYY-MM-DD'),
    (SELECT TREAT(REF(k) AS REF t_klient_firm) FROM klienci k WHERE id_klienta = 5))
);

-- Kierowca dla Comarch
INSERT INTO kierowcy_firmowi VALUES (
    t_kierowca_firmowy(2, 'Tomasz', 'Kot', 'DO67890', 'PJ002', TO_DATE('1992-11-15','YYYY-MM-DD'),
    (SELECT TREAT(REF(k) AS REF t_klient_firm) FROM klienci k WHERE id_klienta = 6))
);

-- Kierowca dla Orlen
INSERT INTO kierowcy_firmowi VALUES (
    t_kierowca_firmowy(3, 'Krzysztof', 'Nowak', 'DO54321', 'PJ003', TO_DATE('1975-01-30','YYYY-MM-DD'),
    (SELECT TREAT(REF(k) AS REF t_klient_firm) FROM klienci k WHERE id_klienta = 7))
);

-- Kierowca dla CD Projekt
INSERT INTO kierowcy_firmowi VALUES (
    t_kierowca_firmowy(4, 'Marcin', 'Gierkowski', 'DO09876', 'PJ004', TO_DATE('1988-07-07','YYYY-MM-DD'),
    (SELECT TREAT(REF(k) AS REF t_klient_firm) FROM klienci k WHERE id_klienta = 8))
);

INSERT INTO kontrakty VALUES (
    seq_kontrakty.NEXTVAL, 
    (SELECT TREAT(REF(k) AS REF t_klient_firm) FROM klienci k WHERE id_klienta = 7), 
    SYSDATE+365, -- Ważny rok
    0.20,        -- 20% rabatu
    100000       -- Limit kredytowy
);

COMMIT;

-- Przegląd zawartości tabel
SELECT k.nazwa, k.cena_za_dobe || ' PLN' as cena, k.kaucja || ' PLN' as kaucja, k.limit_km as limit_km, k.cena_ubezp_full as ubezp_full
FROM klasy_samochodow k
ORDER BY k.id_klasy;

SELECT s.id_auta, s.marka, s.model, s.nr_rejestracyjny, s.aktualny_przebieg, s.status_auta,
       DEREF(s.ref_klasa).nazwa AS klasa_auta
FROM samochody s
ORDER BY s.id_auta;

SELECT k.id_klienta, k.email, k.adres.miasto || ', ' || k.adres.ulica || ' ' || k.adres.nr_domu AS adres,
       TREAT(VALUE(k) AS t_klient_ind).imie AS imie,
       TREAT(VALUE(k) AS t_klient_ind).nazwisko AS nazwisko,
       TREAT(VALUE(k) AS t_klient_firm).nazwa_firmy AS nazwa_firmy,
       TREAT(VALUE(k) AS t_klient_firm).nip AS nip
FROM klienci k
ORDER BY k.id_klienta;

SELECT k.imie || ' ' || k.nazwisko AS kierowca, k.pesel_lub_dowod, k.nr_prawa_jazdy,
       DEREF(k.ref_firma).nazwa_firmy AS pracuje_dla,
       DEREF(k.ref_firma).nip AS nip_firmy
FROM kierowcy_firmowi k
ORDER BY k.id_kierowcy;

SELECT w.id_wypozyczenia, w.data_od, w.data_do_planowana, w.status_realizacji, w.status_platnosci,
       DEREF(w.ref_auto).marka || ' ' || DEREF(w.ref_auto).model AS auto,
       DEREF(w.ref_klient).email AS klient
FROM wypozyczenia w
ORDER BY w.id_wypozyczenia;

SELECT w.id_wypozyczenia AS ID_WYP, t.data_wplaty, t.kwota, t.metoda_platnosci
FROM wypozyczenia w, TABLE(w.lista_wplat) t
ORDER BY w.id_wypozyczenia;

SELECT w.id_wypozyczenia AS ID_WYP, r.typ_kosztu, r.kwota
FROM wypozyczenia w, TABLE(w.lista_rozliczen) r
ORDER BY w.id_wypozyczenia;

SELECT p.id_protokolu, p.typ_protokolu, p.opis_stanu, p.czy_uszkodzony, p.szacowany_koszt_naprawy,
       DEREF(p.ref_wypozyczenie).id_wypozyczenia AS dotyczy_wypozyczenia
FROM protokoly_uszkodzen p;

-- Testowanie funkcjonalności

-- 1. Utworzenie standardowej rezerwacji
BEGIN
    pkg_wynajem.utworz_rezerwacje(p_id_klienta => 1, p_id_auta => 211, p_data_od => SYSDATE, p_dni => 3, p_ubezp => 'FULL', p_zagranica => 'N');
    DBMS_OUTPUT.PUT_LINE('Rezerwacja utworzona pomyślnie.');
END;
/

-- 2. Wydanie auta
BEGIN
    pkg_wynajem.zaksieguj_wplate(1, 2150, 'KARTA');
    pkg_wynajem.wydaj_samochod(1);
    DBMS_OUTPUT.PUT_LINE('Auto wydane.');
END;
/

-- 3. Zwrot auta (powoduje status BRUDNY)
BEGIN
    pkg_zwroty.przetworz_zwrot(1, 80300, 100, 'N');
    DBMS_OUTPUT.PUT_LINE('Auto zwrócone.');
END;
/

-- 4. Przywrócenie do floty
BEGIN
    pkg_zwroty.przywroc_do_floty(211);
END;
/

-- 5. Test blokady klienta
-- Najpierw blokujemy klienta
UPDATE klienci k SET k.czy_zablokowany = 1 WHERE id_klienta = 2;
COMMIT;

BEGIN
    pkg_wynajem.utworz_rezerwacje(p_id_klienta => 2, p_id_auta => 201, p_data_od => SYSDATE, p_dni => 2, p_ubezp => 'STD', p_zagranica => 'N');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Oczekiwany błąd: ' || SQLERRM);
END;
/

-- 6. Test anulowania
BEGIN
    pkg_wynajem.utworz_rezerwacje(1, 206, SYSDATE+10, 2, 'STD', 'N');
    pkg_wynajem.anuluj_rezerwacje(2);
    DBMS_OUTPUT.PUT_LINE('Rezerwacja anulowana pomyślnie.');
END;
/

-- 7. Przykładowe zapytania dla ról

-- PRACOWNIK

-- a) Nowa Rezerwacja (Rejestracja transakcji):
BEGIN
    pkg_wynajem.utworz_rezerwacje(p_id_klienta => 1, p_id_auta => 211, p_data_od => SYSDATE, p_dni => 3, p_ubezp => 'FULL', p_zagranica => 'N');
END;
/

SELECT w.id_wypozyczenia, w.data_od, w.data_do_planowana, w.status_realizacji, w.status_platnosci,
       DEREF(w.ref_auto).marka || ' ' || DEREF(w.ref_auto).model AS auto,
       DEREF(w.ref_klient).email AS klient
FROM wypozyczenia w
WHERE w.id_wypozyczenia = (SELECT MAX(id_wypozyczenia) FROM wypozyczenia);

-- b) Przyjęcie Płatności (Dodanie elementu do kolekcji):
BEGIN
    pkg_wynajem.zaksieguj_wplate(p_id_wyp => 3, p_kwota => 5600, p_metoda => 'KARTA');
END;
/

SELECT w.id_wypozyczenia, w.status_platnosci, t.data_wplaty, t.kwota, t.metoda_platnosci
FROM wypozyczenia w, TABLE(w.lista_wplat) t
WHERE w.id_wypozyczenia = 3;

-- c) Wydanie Samochodu:
BEGIN
    pkg_wynajem.wydaj_samochod(p_id_wyp => 3);
END;
/

SELECT w.id_wypozyczenia, w.status_realizacji, w.przebieg_start, s.status_auta AS status_w_tabeli_aut
FROM wypozyczenia w
JOIN samochody s ON DEREF(w.ref_auto).id_auta = s.id_auta
WHERE w.id_wypozyczenia = 3;

-- d) Zwrot Samochodu (Rozliczenie kar):
BEGIN
    pkg_zwroty.przetworz_zwrot(p_id_wyp => 3, p_przebieg_koniec => 85200, p_stan_paliwa => 80, p_czy_uszkodzenia => 'N');
END;
/

SELECT w.id_wypozyczenia, w.status_realizacji, w.status_platnosci, r.typ_kosztu, r.kwota AS naliczona_kwota
FROM wypozyczenia w, TABLE(w.lista_rozliczen) r
WHERE w.id_wypozyczenia = 3;


SELECT id_auta, status_auta, aktualny_przebieg 
FROM samochody 
WHERE id_auta = 211;

-----------------------------------------------------------------------------------------
-- TEST -- Zwrotu uszkodzonego auta/przekroczenia kilometrów
SELECT id_wypozyczenia, status_realizacji, data_od 
FROM wypozyczenia 
ORDER BY id_wypozyczenia DESC;

--Rezerwacja,opłata,wydanie
BEGIN
    pkg_wynajem.utworz_rezerwacje(p_id_klienta => 3, p_id_auta => 201, p_data_od => SYSDATE, p_dni => 1, p_ubezp => 'STD', p_zagranica => 'N');
END;
/
BEGIN
    pkg_wynajem.zaksieguj_wplate(p_id_wyp => 4, p_kwota => 1100, p_metoda => 'BLIK');
    pkg_wynajem.wydaj_samochod(p_id_wyp => 4);
END;
/

SELECT w.id_wypozyczenia, w.status_realizacji, w.przebieg_start, s.status_auta AS status_w_tabeli_aut
FROM wypozyczenia w
JOIN samochody s ON DEREF(w.ref_auto).id_auta = s.id_auta
WHERE w.id_wypozyczenia = 4;

--Zwrot
BEGIN
    pkg_zwroty.przetworz_zwrot(p_id_wyp => 4, p_przebieg_koniec => 47800, p_stan_paliwa => 100, p_czy_uszkodzenia => 'T');
END;
/

--Status auta + Końcowy poniesiony koszt
SELECT 
    s.id_auta,
    s.marka || ' ' || s.model AS auto,
    s.status_auta,
    r.typ_kosztu AS "POZYCJA NA RACHUNKU",
    r.kwota || ' PLN' AS "KOSZT"
FROM 
    wypozyczenia w,
    samochody s,
    TABLE(w.lista_rozliczen) r
WHERE 
    w.id_wypozyczenia = (SELECT MAX(id_wypozyczenia) FROM wypozyczenia)
    AND s.id_auta = DEREF(w.ref_auto).id_auta;


-- KIEROWNIK

-- a) Analiza Finansowa:
SELECT w.id_wypozyczenia,
       DEREF(w.ref_klient).email AS klient,
       r.typ_kosztu,
       r.kwota
FROM wypozyczenia w,
     TABLE(w.lista_rozliczen) r;

-- b) Raport Historii Klienta (Wykorzystanie Ref Kursora):
DECLARE
    v_cur SYS_REFCURSOR;
    v_data DATE;
    v_auto VARCHAR2(100);
    v_status VARCHAR2(50);
    v_platnosc VARCHAR2(50);
BEGIN
    v_cur := pkg_raporty.pobierz_historie_klienta(1);

    LOOP
        FETCH v_cur INTO v_data, v_auto, v_status, v_platnosc;
        EXIT WHEN v_cur%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(v_data || ' | ' || v_auto || ' | ' || v_status);
    END LOOP;
    CLOSE v_cur;
END;
/

-- c) Sprawdzenie floty:
SELECT s.marka, s.model, s.status_auta,
       DEREF(s.ref_klasa).nazwa AS klasa,
       DEREF(s.ref_klasa).cena_za_dobe AS stawka
FROM samochody s;




-- TEST: Rezerwacja z akcesoriami (Fotelik + GPS)
DECLARE
    v_dodatki t_lista_ids := t_lista_ids(1, 2);
BEGIN
    pkg_wynajem.utworz_rezerwacje(1, 211, SYSDATE, 3, 'STD', 'N',NULL , v_dodatki);
END;
/

-- każda pozycja kosztorysu: Auto, Kaucja, Ubezpieczenie, Akcesoria
SELECT 
    r.typ_kosztu AS "POZYCJA NA RACHUNKU",
    r.kwota || ' PLN' AS "KOSZT"
FROM wypozyczenia w, TABLE(w.lista_rozliczen) r
WHERE w.id_wypozyczenia = (SELECT MAX(id_wypozyczenia) FROM wypozyczenia);

-- co dokładnie zostało dodane do auta
SELECT 
    DEREF(a.ref_akcesorium).nazwa AS "AKCESORIUM",
    a.cena_w_dniu_wynajmu || ' PLN' AS "CENA ZA DOBĘ"
FROM wypozyczenia w, TABLE(w.lista_akcesoriow) a
WHERE w.id_wypozyczenia = (SELECT MAX(id_wypozyczenia) FROM wypozyczenia);



-- TEST: Próba wpłaty za małej kwoty
BEGIN
    pkg_wynajem.zaksieguj_wplate(seq_wypozyczenia.CURRVAL, 50, 'KARTA');
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/




-- TEST: Ograniczenie wiekowe
INSERT INTO klienci VALUES (
    t_klient_ind(99, 'mlody@test.pl', '999999999', 0,
    t_adres('Wawa', 'Testowa', '1', '', '00-000'), 
    'Młody', 'Kierowca', '05210112345', SYSDATE - (19*365))
);
COMMIT;

BEGIN
    pkg_wynajem.utworz_rezerwacje(99, 202, SYSDATE, 2, 'STD', 'N');
END;
/



-- TEST: Kolizja terminów
SELECT id_wypozyczenia, status_realizacji, data_od 
FROM wypozyczenia 
ORDER BY id_wypozyczenia DESC;

BEGIN
    pkg_wynajem.utworz_rezerwacje(p_id_klienta => 4, p_id_auta => 213, p_data_od => SYSDATE, p_dni => 3, p_ubezp => 'STD', p_zagranica => 'N');
END;
/
BEGIN
    pkg_wynajem.utworz_rezerwacje(p_id_klienta => 3, p_id_auta => 213, p_data_od => SYSDATE+4, p_dni => 3, p_ubezp => 'STD', p_zagranica => 'N');
END;
/

BEGIN
    pkg_wynajem.przedluz_najem(7, SYSDATE+4);
END;
/

BEGIN
    pkg_wynajem.zaksieguj_wplate(p_id_wyp => 7, p_kwota => 2000, p_metoda => 'BLIK');
    pkg_wynajem.wydaj_samochod(p_id_wyp => 7);
END;
/

BEGIN
    pkg_wynajem.utworz_rezerwacje(2, 206, SYSDATE, 2, 'STD', 'N');
    pkg_wynajem.przedluz_najem(6, SYSDATE+4);

END;
/


-- TEST: Udzielenie rabatu
BEGIN
    pkg_wynajem.utworz_rezerwacje(p_id_klienta => 1, p_id_auta => 216, p_data_od => SYSDATE, p_dni => 5, p_ubezp => 'STD', p_zagranica => 'N');
END;
/



SELECT id_wypozyczenia, status_realizacji, data_od, przebieg_start
FROM wypozyczenia 
ORDER BY id_wypozyczenia DESC;


-- FIRMA --
BEGIN
    pkg_wynajem.utworz_rezerwacje(p_id_klienta => 7, p_id_auta => 226, p_data_od => SYSDATE+2, p_dni => 3, p_ubezp => 'FULL', p_zagranica => 'N',p_id_kierowcy => 3);
END;
/

BEGIN
    pkg_wynajem.wydaj_samochod(p_id_wyp => 9);
END;
/
BEGIN
    pkg_zwroty.przetworz_zwrot(p_id_wyp => 9, p_przebieg_koniec => 45000, p_stan_paliwa => 100, p_czy_uszkodzenia => 'N');
END;
/

BEGIN
    generuj_fakture_zbiorcza(7);
END;
/

