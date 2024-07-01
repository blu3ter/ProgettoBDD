--
-- PostgreSQL database dump
--

-- Dumped from database version 14.10
-- Dumped by pg_dump version 16.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: social_group; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA social_group;


ALTER SCHEMA social_group OWNER TO postgres;

--
-- Name: reazione; Type: DOMAIN; Schema: social_group; Owner: postgres
--

CREATE DOMAIN social_group.reazione AS character varying(20)
	CONSTRAINT reazione_check CHECK (((VALUE)::text = ANY ((ARRAY['Mi_piace'::character varying, 'Cuore'::character varying, 'Sorpreso'::character varying, 'Arrabbiato'::character varying])::text[])));


ALTER DOMAIN social_group.reazione OWNER TO postgres;

--
-- Name: admin_partecipante(); Type: FUNCTION; Schema: social_group; Owner: postgres
--

CREATE FUNCTION social_group.admin_partecipante() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
    INSERT INTO partecipante
        VALUES(new.data_Creazione,new.email_admin, new.titolo);
        return new;
    end;
$$;


ALTER FUNCTION social_group.admin_partecipante() OWNER TO postgres;

--
-- Name: aggiorna_email_admin(); Type: FUNCTION; Schema: social_group; Owner: postgres
--

CREATE FUNCTION social_group.aggiorna_email_admin() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
      partecipanti INT := 0;
BEGIN
    SELECT COUNT(*) INTO partecipanti
    FROM social_group.partecipante
    WHERE Titolo_gruppo = old.titolo_gruppo;

    IF EXISTS (
        SELECT 1
        FROM social_group.gruppo
        WHERE titolo = old.titolo_gruppo
          AND email_admin = OLD.email_partecipante
    ) 
        AND partecipanti > 0
    
        THEN
        UPDATE social_group.gruppo
        SET Email_admin = (
            SELECT email_partecipante
            FROM social_group.partecipante
            WHERE Titolo_gruppo = OLD.Titolo_Gruppo
            ORDER BY data_iscrizione DESC
            LIMIT 1)
        WHERE titolo = old.Titolo_gruppo;
   
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION social_group.aggiorna_email_admin() OWNER TO postgres;

--
-- Name: avvisa_utenti(); Type: FUNCTION; Schema: social_group; Owner: postgres
--

CREATE FUNCTION social_group.avvisa_utenti() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE

    creator varchar(100);

scorri_email CURSOR FOR
Select email_partecipante, Titolo_gruppo from social_group.partecipante
WHERE Titolo_gruppo =
(Select gruppo_app from contenuto where id_contenuto = NEW.id_contenuto)
    AND email_partecipante <> creator;

Email varchar(100);
Titolo_gruppo varchar(30);


BEGIN

   Select email_partecipante into creator FROM  social_group.partecipante WHERE email_partecipante =
                    (Select email_utente from contenuto where id_contenuto = NEW.id_contenuto);

OPEN scorri_email;
LOOP
FETCH scorri_email into Email,Titolo_gruppo;
EXIT WHEN NOT FOUND ;
INSERT INTO avvisa
VALUES(Email,Titolo_gruppo,new.id_notifica);
END LOOP;
CLOSE scorri_email;

return new;

END;
$$;


ALTER FUNCTION social_group.avvisa_utenti() OWNER TO postgres;

--
-- Name: date_coerenti(); Type: FUNCTION; Schema: social_group; Owner: postgres
--

CREATE FUNCTION social_group.date_coerenti() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Ottieni la data del contenuto corrispondente
    DECLARE
        data_contenuto DATE;
    BEGIN
        SELECT data INTO data_contenuto
        FROM contenuto
        WHERE id_contenuto = NEW.id_contenuto;

        -- Verifica se la data del commento è più recente
        IF NEW.data > data_contenuto THEN
            RAISE EXCEPTION 'La data del commento deve essere più recente della data del contenuto';
        END IF;
    END;
    RETURN NEW;
END;
$$;


ALTER FUNCTION social_group.date_coerenti() OWNER TO postgres;

--
-- Name: elimina_gruppo_vuoto(); Type: FUNCTION; Schema: social_group; Owner: postgres
--

CREATE FUNCTION social_group.elimina_gruppo_vuoto() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    partecipanti INT := 0;
BEGIN
    SELECT COUNT(*) INTO partecipanti
    FROM social_group.partecipante
    WHERE Titolo_gruppo = old.titolo_gruppo;

    IF partecipanti = 0 THEN
        DELETE FROM social_group.gruppo
        WHERE Titolo = old.titolo_gruppo;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION social_group.elimina_gruppo_vuoto() OWNER TO postgres;

--
-- Name: genera_notifica(); Type: FUNCTION; Schema: social_group; Owner: postgres
--

CREATE FUNCTION social_group.genera_notifica() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

        DECLARE
        gruppo varchar(30);

        BEGIN
           SELECT gruppo_app INTO gruppo
            FROM social_group.contenuto
            WHERE id_contenuto =new.id_contenuto;

        INSERT INTO notifica(id_contenuto,testo,data)VALUES
        (new.id_contenuto,'è appena stato caricato un contenuto in: '||gruppo||'.',now());


        RETURN NEW;



        end;
      $$;


ALTER FUNCTION social_group.genera_notifica() OWNER TO postgres;

--
-- Name: like_coerenti(); Type: FUNCTION; Schema: social_group; Owner: postgres
--

CREATE FUNCTION social_group.like_coerenti() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

    DECLARE
        data_like DATE;
    BEGIN
        SELECT data INTO data_like
        FROM contenuto
        WHERE id_contenuto = NEW.id_contenuto;


        IF NEW.data <= data_like THEN
            RAISE EXCEPTION 'La data del like deve essere più recente della data del contenuto';
        END IF;
    END;
    RETURN NEW;
END;
$$;


ALTER FUNCTION social_group.like_coerenti() OWNER TO postgres;

--
-- Name: lunghezza_password(); Type: FUNCTION; Schema: social_group; Owner: postgres
--

CREATE FUNCTION social_group.lunghezza_password() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF LENGTH(NEW.password) < 8 THEN
        RAISE EXCEPTION 'La password deve essere lunga almeno 8 caratteri';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION social_group.lunghezza_password() OWNER TO postgres;

--
-- Name: verifica_commento(); Type: FUNCTION; Schema: social_group; Owner: postgres
--

CREATE FUNCTION social_group.verifica_commento() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  DECLARE gruppo varchar(30);

BEGIN
    --
    SELECT gruppo_app INTO gruppo
    FROM social_group.contenuto
    WHERE id_contenuto = NEW.id_contenuto;

    --
    IF NEW.gruppo_riferimento <> gruppo THEN
        RAISE EXCEPTION 'Prima di commentare, devi iscriverti al gruppo in cui è stato postato il contenuto';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION social_group.verifica_commento() OWNER TO postgres;

--
-- Name: verifica_mi_piace(); Type: FUNCTION; Schema: social_group; Owner: postgres
--

CREATE FUNCTION social_group.verifica_mi_piace() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE gruppo varchar(30);
BEGIN

    SELECT gruppo_app INTO gruppo
    FROM social_group.contenuto
    WHERE id_contenuto = NEW.id_contenuto;

    -- Verifica se il gruppo di riferimento del partecipante è uguale al gruppo di riferimento del contenuto
    IF NEW.titolo_gruppo <> gruppo THEN
        RAISE EXCEPTION 'Prima di inserire una reazione, devi iscriverti al gruppo in cui è stato postato il contenuto';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION social_group.verifica_mi_piace() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: avvisa; Type: TABLE; Schema: social_group; Owner: postgres
--

CREATE TABLE social_group.avvisa (
    email_destinatario character varying(100) NOT NULL,
    gruppo_da_cui_avvisato character varying(30) NOT NULL,
    id_notifica integer
);


ALTER TABLE social_group.avvisa OWNER TO postgres;

--
-- Name: commento; Type: TABLE; Schema: social_group; Owner: postgres
--

CREATE TABLE social_group.commento (
    id_contenuto integer,
    email_partecipante character varying(100) NOT NULL,
    gruppo_riferimento character varying(30) NOT NULL,
    testo character varying(300) NOT NULL,
    data date NOT NULL
);


ALTER TABLE social_group.commento OWNER TO postgres;

--
-- Name: contenuto; Type: TABLE; Schema: social_group; Owner: postgres
--

CREATE TABLE social_group.contenuto (
    id_contenuto integer NOT NULL,
    testo character varying(300) NOT NULL,
    data date NOT NULL,
    gruppo_app character varying(30) NOT NULL,
    email_utente character varying(100) NOT NULL
);


ALTER TABLE social_group.contenuto OWNER TO postgres;

--
-- Name: contenuto_id_contenuto_seq; Type: SEQUENCE; Schema: social_group; Owner: postgres
--

CREATE SEQUENCE social_group.contenuto_id_contenuto_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE social_group.contenuto_id_contenuto_seq OWNER TO postgres;

--
-- Name: contenuto_id_contenuto_seq; Type: SEQUENCE OWNED BY; Schema: social_group; Owner: postgres
--

ALTER SEQUENCE social_group.contenuto_id_contenuto_seq OWNED BY social_group.contenuto.id_contenuto;


--
-- Name: dbprogetto; Type: TABLE; Schema: social_group; Owner: postgres
--

CREATE TABLE social_group.dbprogetto (
);


ALTER TABLE social_group.dbprogetto OWNER TO postgres;

--
-- Name: gruppo; Type: TABLE; Schema: social_group; Owner: postgres
--

CREATE TABLE social_group.gruppo (
    titolo character varying(30) NOT NULL,
    descrizione character varying(255),
    data_creazione date,
    categoria character varying(50) NOT NULL,
    email_admin character varying(100),
    CONSTRAINT data_creazione CHECK ((data_creazione <= CURRENT_DATE))
);


ALTER TABLE social_group.gruppo OWNER TO postgres;

--
-- Name: mi_piace; Type: TABLE; Schema: social_group; Owner: postgres
--

CREATE TABLE social_group.mi_piace (
    id_contenuto integer NOT NULL,
    titolo_gruppo character varying(30) NOT NULL,
    email_partecipante character varying(100) NOT NULL,
    tipo_like social_group.reazione NOT NULL,
    data date NOT NULL
);


ALTER TABLE social_group.mi_piace OWNER TO postgres;

--
-- Name: notifica; Type: TABLE; Schema: social_group; Owner: postgres
--

CREATE TABLE social_group.notifica (
    id_notifica integer NOT NULL,
    id_contenuto integer,
    testo character varying(100),
    data date NOT NULL,
    CONSTRAINT controllo_data CHECK ((data <= CURRENT_DATE))
);


ALTER TABLE social_group.notifica OWNER TO postgres;

--
-- Name: notifica_id_notifica_seq; Type: SEQUENCE; Schema: social_group; Owner: postgres
--

CREATE SEQUENCE social_group.notifica_id_notifica_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE social_group.notifica_id_notifica_seq OWNER TO postgres;

--
-- Name: notifica_id_notifica_seq; Type: SEQUENCE OWNED BY; Schema: social_group; Owner: postgres
--

ALTER SEQUENCE social_group.notifica_id_notifica_seq OWNED BY social_group.notifica.id_notifica;


--
-- Name: partecipante; Type: TABLE; Schema: social_group; Owner: postgres
--

CREATE TABLE social_group.partecipante (
    data_iscrizione date NOT NULL,
    email_partecipante character varying(100) NOT NULL,
    titolo_gruppo character varying(30) NOT NULL
);


ALTER TABLE social_group.partecipante OWNER TO postgres;

--
-- Name: segue; Type: TABLE; Schema: social_group; Owner: postgres
--

CREATE TABLE social_group.segue (
    email_utente1 character varying(100),
    email_utente2 character varying(100)
);


ALTER TABLE social_group.segue OWNER TO postgres;

--
-- Name: utente; Type: TABLE; Schema: social_group; Owner: postgres
--

CREATE TABLE social_group.utente (
    email character varying(100) NOT NULL,
    nome character varying(30) NOT NULL,
    cognome character varying(30) NOT NULL,
    username character varying(100),
    password character varying(30) NOT NULL,
    bio character varying(100)
);


ALTER TABLE social_group.utente OWNER TO postgres;

--
-- Name: contenuto id_contenuto; Type: DEFAULT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.contenuto ALTER COLUMN id_contenuto SET DEFAULT nextval('social_group.contenuto_id_contenuto_seq'::regclass);


--
-- Name: notifica id_notifica; Type: DEFAULT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.notifica ALTER COLUMN id_notifica SET DEFAULT nextval('social_group.notifica_id_notifica_seq'::regclass);


--
-- Data for Name: avvisa; Type: TABLE DATA; Schema: social_group; Owner: postgres
--

COPY social_group.avvisa (email_destinatario, gruppo_da_cui_avvisato, id_notifica) FROM stdin;
Bennycara@studenti.unina.it	Samsung: news and updates	25
Baldi@gmail.com	Samsung: news and updates	25
Bennycara@studenti.unina.it	Samsung: news and updates	26
Baldi@gmail.com	Samsung: news and updates	26
Antoniocampagna@gmail.com	Samsung: news and updates	26
Alfonso44@gmail.com	Samsung: news and updates	26
Giovanni@gmail.com	Samsung: news and updates	26
ricciomarien11@gmail.com	Samsung: news and updates	26
Alfonso44@gmail.com	minecraftITA	27
ricciomarien11@gmail.com	minecraftITA	27
Baldi@gmail.com	minecraftITA	27
Antoniocampagna@gmail.com	minecraftITA	27
Alfonso44@gmail.com	codici c++ e java	28
Bennycara@studenti.unina.it	codici c++ e java	28
Antoniocampagna@gmail.com	codici c++ e java	28
Baldi@gmail.com	codici c++ e java	28
Alfonso44@gmail.com	minecraftITA	29
ricciomarien11@gmail.com	minecraftITA	29
Baldi@gmail.com	minecraftITA	29
Alfonso44@gmail.com	minecraftITA	30
Baldi@gmail.com	minecraftITA	30
Antoniocampagna@gmail.com	minecraftITA	30
Bennycara@studenti.unina.it	Samsung: news and updates	32
Baldi@gmail.com	Samsung: news and updates	32
Antoniocampagna@gmail.com	Samsung: news and updates	32
Alfonso44@gmail.com	Samsung: news and updates	32
Giovanni@gmail.com	Samsung: news and updates	32
simone.sc.catenaccio@gmail.com	codici c++ e java	33
Alfonso44@gmail.com	codici c++ e java	33
Bennycara@studenti.unina.it	codici c++ e java	33
Antoniocampagna@gmail.com	codici c++ e java	33
Baldi@gmail.com	codici c++ e java	33
\.


--
-- Data for Name: commento; Type: TABLE DATA; Schema: social_group; Owner: postgres
--

COPY social_group.commento (id_contenuto, email_partecipante, gruppo_riferimento, testo, data) FROM stdin;
30	Alfonso44@gmail.com	codici c++ e java	resterò fedele al for semplice	2024-04-16
29	ricciomarien11@gmail.com	minecraftITA	L avevo fatto prima di lui!	2024-04-16
29	Alfonso44@gmail.com	minecraftITA	Mariano ma noi non interessa niente proprio!	2024-04-16
\.


--
-- Data for Name: contenuto; Type: TABLE DATA; Schema: social_group; Owner: postgres
--

COPY social_group.contenuto (id_contenuto, testo, data, gruppo_app, email_utente) FROM stdin;
27	bella regaaaaa	2024-04-15	Samsung: news and updates	Baldi@gmail.com
28	Il galaxy watch è inutile non buttate i soldi vi prego!	2024-04-16	Samsung: news and updates	Bennycara@studenti.unina.it
29	Non ci credo lollino ha droppato una nuova farm infinita	2024-04-16	minecraftITA	Baldi@gmail.com
30	oggi ho usato il for potenziato, devo dire che è molto meglio del normale. Ve lo consiglio,fate qualche ricerca su Google	2024-04-16	codici c++ e java	Baldi@gmail.com
31	I diamanti sono diventati troppo difficili da trovare	2024-04-16	minecraftITA	Antoniocampagna@gmail.com
33	puntata 500	2024-06-19	minecraftITA	ricciomarien11@gmail.com
35	Quando esce l's25?	2024-06-19	Samsung: news and updates	ricciomarien11@gmail.com
36	ba bi	2024-06-23	codici c++ e java	ricciomarien11@gmail.com
\.


--
-- Data for Name: dbprogetto; Type: TABLE DATA; Schema: social_group; Owner: postgres
--

COPY social_group.dbprogetto  FROM stdin;
\.


--
-- Data for Name: gruppo; Type: TABLE DATA; Schema: social_group; Owner: postgres
--

COPY social_group.gruppo (titolo, descrizione, data_creazione, categoria, email_admin) FROM stdin;
minecraftITA	lollolacustre	2024-04-15	giochi	Alfonso44@gmail.com
codici c++ e java	il titolo parla da solo, se avete idee per rendere qualche funzione gia esistente pubblicatelo(non postate codici in pascal	2024-04-16	Informatica	Alfonso44@gmail.com
motogp4ever	tutte le news,idee ed opinioni della motogp verrano apprezzate	2024-04-16	sport	Baldi@gmail.com
Samsung: news and updates	tutti gli agg samsung	2024-04-15	informatica	Bennycara@studenti.unina.it
\.


--
-- Data for Name: mi_piace; Type: TABLE DATA; Schema: social_group; Owner: postgres
--

COPY social_group.mi_piace (id_contenuto, titolo_gruppo, email_partecipante, tipo_like, data) FROM stdin;
\.


--
-- Data for Name: notifica; Type: TABLE DATA; Schema: social_group; Owner: postgres
--

COPY social_group.notifica (id_notifica, id_contenuto, testo, data) FROM stdin;
25	27	è appena stato caricato un contenuto in: Samsung: news and updates.	2024-04-15
26	28	è appena stato caricato un contenuto in: Samsung: news and updates.	2024-04-16
27	29	è appena stato caricato un contenuto in: minecraftITA.	2024-04-16
28	30	è appena stato caricato un contenuto in: codici c++ e java.	2024-04-16
29	31	è appena stato caricato un contenuto in: minecraftITA.	2024-04-16
30	33	è appena stato caricato un contenuto in: minecraftITA.	2024-06-19
32	35	è appena stato caricato un contenuto in: Samsung: news and updates.	2024-06-19
33	36	è appena stato caricato un contenuto in: codici c++ e java.	2024-06-23
\.


--
-- Data for Name: partecipante; Type: TABLE DATA; Schema: social_group; Owner: postgres
--

COPY social_group.partecipante (data_iscrizione, email_partecipante, titolo_gruppo) FROM stdin;
2024-06-19	Giovanni@gmail.com	minecraftITA
2024-06-19	Giovanni@gmail.com	motogp4ever
2024-06-19	ricciomarien11@gmail.com	codici c++ e java
2024-06-19	simone.sc.catenaccio@gmail.com	minecraftITA
2024-06-19	simone.sc.catenaccio@gmail.com	codici c++ e java
2024-06-20	ricciomarien11@gmail.com	motogp4ever
2024-06-20	simone.sc.catenaccio@gmail.com	Samsung: news and updates
2024-06-23	Bennycara@studenti.unina.it	minecraftITA
2024-04-15	Bennycara@studenti.unina.it	Samsung: news and updates
2024-04-15	Baldi@gmail.com	Samsung: news and updates
2024-04-15	Alfonso44@gmail.com	minecraftITA
2024-04-16	Alfonso44@gmail.com	codici c++ e java
2024-04-16	Baldi@gmail.com	motogp4ever
2024-04-16	Antoniocampagna@gmail.com	Samsung: news and updates
2024-04-16	Alfonso44@gmail.com	Samsung: news and updates
2024-04-16	Giovanni@gmail.com	Samsung: news and updates
2024-04-16	ricciomarien11@gmail.com	Samsung: news and updates
2024-04-16	ricciomarien11@gmail.com	minecraftITA
2024-04-16	Baldi@gmail.com	minecraftITA
2024-04-16	Antoniocampagna@gmail.com	minecraftITA
2024-04-16	Bennycara@studenti.unina.it	codici c++ e java
2024-04-16	Antoniocampagna@gmail.com	codici c++ e java
2024-04-16	Baldi@gmail.com	codici c++ e java
2024-04-16	marcorossi@live.it	motogp4ever
\.


--
-- Data for Name: segue; Type: TABLE DATA; Schema: social_group; Owner: postgres
--

COPY social_group.segue (email_utente1, email_utente2) FROM stdin;
\.


--
-- Data for Name: utente; Type: TABLE DATA; Schema: social_group; Owner: postgres
--

COPY social_group.utente (email, nome, cognome, username, password, bio) FROM stdin;
ricciomarien11@gmail.com	mariano	riccio	magicu11	napoli1926	
Bennycara@studenti.unina.it	Benedetta	Carandente	Cavabett	Ciao1234	sii sempre te stesso
Antoniocampagna@gmail.com	Antonio	Campagna	Danut	Danutciampaglia	
Baldi@gmail.com	Vincenzo	Baldassarre	Bakugan	ooooooo1	i leoni rimangono leoni 
Giovanni@gmail.com	Giovanni	La roccia	Laroccia22	ciaociao10	uffa
Alfonso44@gmail.com	Alfonso	Lombo	Alfonso44	oooooooooo	
marcorossi@live.it	marco	rossi	rossicè	valerossi46	amo gli sport
simone.sc.catenaccio@gmail.com	Simone	Catenaccio	blu3ter	Ciaociao10	Voglio conoscere gli studenti della FED2
\.


--
-- Name: contenuto_id_contenuto_seq; Type: SEQUENCE SET; Schema: social_group; Owner: postgres
--

SELECT pg_catalog.setval('social_group.contenuto_id_contenuto_seq', 36, true);


--
-- Name: notifica_id_notifica_seq; Type: SEQUENCE SET; Schema: social_group; Owner: postgres
--

SELECT pg_catalog.setval('social_group.notifica_id_notifica_seq', 33, true);


--
-- Name: contenuto contenuto_pkey; Type: CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.contenuto
    ADD CONSTRAINT contenuto_pkey PRIMARY KEY (id_contenuto);


--
-- Name: gruppo gruppo_pkey; Type: CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.gruppo
    ADD CONSTRAINT gruppo_pkey PRIMARY KEY (titolo);


--
-- Name: notifica notifica_pkey; Type: CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.notifica
    ADD CONSTRAINT notifica_pkey PRIMARY KEY (id_notifica);


--
-- Name: mi_piace pk_like; Type: CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.mi_piace
    ADD CONSTRAINT pk_like PRIMARY KEY (id_contenuto, titolo_gruppo, email_partecipante);


--
-- Name: partecipante pk_partecipante; Type: CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.partecipante
    ADD CONSTRAINT pk_partecipante PRIMARY KEY (email_partecipante, titolo_gruppo);


--
-- Name: segue uq_segue; Type: CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.segue
    ADD CONSTRAINT uq_segue UNIQUE (email_utente1, email_utente2);


--
-- Name: utente utente_pkey; Type: CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.utente
    ADD CONSTRAINT utente_pkey PRIMARY KEY (email);


--
-- Name: utente utente_username_key; Type: CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.utente
    ADD CONSTRAINT utente_username_key UNIQUE (username);


--
-- Name: utente password_length_trigger; Type: TRIGGER; Schema: social_group; Owner: postgres
--

CREATE TRIGGER password_length_trigger BEFORE INSERT ON social_group.utente FOR EACH ROW EXECUTE FUNCTION social_group.lunghezza_password();


--
-- Name: gruppo tr_admin_partecipante; Type: TRIGGER; Schema: social_group; Owner: postgres
--

CREATE TRIGGER tr_admin_partecipante AFTER INSERT ON social_group.gruppo FOR EACH ROW EXECUTE FUNCTION social_group.admin_partecipante();


--
-- Name: partecipante tr_aggiorna_email_admin; Type: TRIGGER; Schema: social_group; Owner: postgres
--

CREATE TRIGGER tr_aggiorna_email_admin AFTER DELETE ON social_group.partecipante FOR EACH ROW EXECUTE FUNCTION social_group.aggiorna_email_admin();


--
-- Name: notifica tr_avvisa_utenti; Type: TRIGGER; Schema: social_group; Owner: postgres
--

CREATE TRIGGER tr_avvisa_utenti AFTER INSERT ON social_group.notifica FOR EACH ROW EXECUTE FUNCTION social_group.avvisa_utenti();


--
-- Name: commento tr_date_coerenti; Type: TRIGGER; Schema: social_group; Owner: postgres
--

CREATE TRIGGER tr_date_coerenti BEFORE INSERT ON social_group.commento FOR EACH ROW EXECUTE FUNCTION social_group.date_coerenti();


--
-- Name: partecipante tr_elimina_gruppo_vuoto; Type: TRIGGER; Schema: social_group; Owner: postgres
--

CREATE TRIGGER tr_elimina_gruppo_vuoto AFTER DELETE ON social_group.partecipante FOR EACH ROW EXECUTE FUNCTION social_group.elimina_gruppo_vuoto();


--
-- Name: contenuto tr_genera_notifica; Type: TRIGGER; Schema: social_group; Owner: postgres
--

CREATE TRIGGER tr_genera_notifica AFTER INSERT ON social_group.contenuto FOR EACH ROW EXECUTE FUNCTION social_group.genera_notifica();


--
-- Name: mi_piace tr_like_coerenti; Type: TRIGGER; Schema: social_group; Owner: postgres
--

CREATE TRIGGER tr_like_coerenti BEFORE INSERT ON social_group.mi_piace FOR EACH ROW EXECUTE FUNCTION social_group.like_coerenti();


--
-- Name: commento tr_verifica_commento; Type: TRIGGER; Schema: social_group; Owner: postgres
--

CREATE TRIGGER tr_verifica_commento BEFORE INSERT ON social_group.commento FOR EACH ROW EXECUTE FUNCTION social_group.verifica_commento();


--
-- Name: mi_piace tr_verifica_mi_piace; Type: TRIGGER; Schema: social_group; Owner: postgres
--

CREATE TRIGGER tr_verifica_mi_piace BEFORE INSERT ON social_group.mi_piace FOR EACH ROW EXECUTE FUNCTION social_group.verifica_mi_piace();


--
-- Name: avvisa fk_avvisa; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.avvisa
    ADD CONSTRAINT fk_avvisa FOREIGN KEY (email_destinatario, gruppo_da_cui_avvisato) REFERENCES social_group.partecipante(email_partecipante, titolo_gruppo) ON DELETE CASCADE;


--
-- Name: contenuto fk_contenuto; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.contenuto
    ADD CONSTRAINT fk_contenuto FOREIGN KEY (gruppo_app, email_utente) REFERENCES social_group.partecipante(titolo_gruppo, email_partecipante) ON DELETE CASCADE;


--
-- Name: gruppo fk_email_admin; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.gruppo
    ADD CONSTRAINT fk_email_admin FOREIGN KEY (email_admin) REFERENCES social_group.utente(email);


--
-- Name: partecipante fk_email_partecipante; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.partecipante
    ADD CONSTRAINT fk_email_partecipante FOREIGN KEY (email_partecipante) REFERENCES social_group.utente(email) ON DELETE CASCADE;


--
-- Name: segue fk_email_utente1; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.segue
    ADD CONSTRAINT fk_email_utente1 FOREIGN KEY (email_utente1) REFERENCES social_group.utente(email) ON DELETE CASCADE;


--
-- Name: segue fk_email_utente2; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.segue
    ADD CONSTRAINT fk_email_utente2 FOREIGN KEY (email_utente2) REFERENCES social_group.utente(email) ON DELETE CASCADE;


--
-- Name: commento fk_id_contenuto; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.commento
    ADD CONSTRAINT fk_id_contenuto FOREIGN KEY (id_contenuto) REFERENCES social_group.contenuto(id_contenuto) ON DELETE CASCADE;


--
-- Name: mi_piace fk_id_contenuto; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.mi_piace
    ADD CONSTRAINT fk_id_contenuto FOREIGN KEY (id_contenuto) REFERENCES social_group.contenuto(id_contenuto);


--
-- Name: notifica fk_id_contenuto; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.notifica
    ADD CONSTRAINT fk_id_contenuto FOREIGN KEY (id_contenuto) REFERENCES social_group.contenuto(id_contenuto) ON DELETE CASCADE;


--
-- Name: avvisa fk_id_notifica; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.avvisa
    ADD CONSTRAINT fk_id_notifica FOREIGN KEY (id_notifica) REFERENCES social_group.notifica(id_notifica) ON DELETE CASCADE;


--
-- Name: commento fk_partecipante; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.commento
    ADD CONSTRAINT fk_partecipante FOREIGN KEY (email_partecipante, gruppo_riferimento) REFERENCES social_group.partecipante(email_partecipante, titolo_gruppo) ON DELETE CASCADE;


--
-- Name: mi_piace fk_partecipante; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.mi_piace
    ADD CONSTRAINT fk_partecipante FOREIGN KEY (titolo_gruppo, email_partecipante) REFERENCES social_group.partecipante(titolo_gruppo, email_partecipante);


--
-- Name: partecipante fk_titolo_gruppo; Type: FK CONSTRAINT; Schema: social_group; Owner: postgres
--

ALTER TABLE ONLY social_group.partecipante
    ADD CONSTRAINT fk_titolo_gruppo FOREIGN KEY (titolo_gruppo) REFERENCES social_group.gruppo(titolo) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

