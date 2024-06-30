create domain reazione as varchar(20)
    constraint reazione_check check ((VALUE)::text = ANY
                                     ((ARRAY ['Mi_piace'::character varying, 'Cuore'::character varying, 'Sorpreso'::character varying, 'Arrabbiato'::character varying])::text[]));

alter domain reazione owner to postgres;

create table utente
(
    email    varchar(100) not null
        primary key,
    nome     varchar(30)  not null,
    cognome  varchar(30)  not null,
    username varchar(100)
        unique,
    password varchar(30)  not null,
    bio      varchar(100)
);

alter table utente
    owner to postgres;

create table gruppo
(
    titolo         varchar(30) not null
        primary key,
    descrizione    varchar(255),
    data_creazione date
        constraint data_creazione
            check (data_creazione <= CURRENT_DATE),
    categoria      varchar(50) not null,
    email_admin    varchar(100)
        constraint fk_email_admin
            references utente
);

alter table gruppo
    owner to postgres;

create table partecipante
(
    data_iscrizione    date         not null,
    email_partecipante varchar(100) not null
        constraint fk_email_partecipante
            references utente
            on delete cascade,
    titolo_gruppo      varchar(30)  not null
        constraint fk_titolo_gruppo
            references gruppo
            on delete cascade,
    constraint pk_partecipante
        primary key (email_partecipante, titolo_gruppo)
);

alter table partecipante
    owner to postgres;

create table contenuto
(
    id_contenuto serial
        primary key,
    testo        varchar(300) not null,
    data         date         not null,
    gruppo_app   varchar(30)  not null,
    email_utente varchar(100) not null,
    constraint fk_contenuto
        foreign key (gruppo_app, email_utente) references partecipante
            on delete cascade
);

alter table contenuto
    owner to postgres;

create table commento
(
    id_contenuto       integer
        constraint fk_id_contenuto
            references contenuto
            on delete cascade,
    email_partecipante varchar(100) not null,
    gruppo_riferimento varchar(30)  not null,
    testo              varchar(300) not null,
    data               date         not null,
    constraint fk_partecipante
        foreign key (email_partecipante, gruppo_riferimento) references partecipante
            on delete cascade
);

alter table commento
    owner to postgres;

create table notifica
(
    id_notifica  serial
        primary key,
    id_contenuto integer
        constraint fk_id_contenuto
            references contenuto
            on delete cascade,
    testo        varchar(100),
    data         date not null
        constraint controllo_data
            check (data <= CURRENT_DATE)
);

alter table notifica
    owner to postgres;

create table avvisa
(
    email_destinatario     varchar(100) not null,
    gruppo_da_cui_avvisato varchar(30)  not null,
    id_notifica            integer
        constraint fk_id_notifica
            references notifica
            on delete cascade,
    constraint fk_avvisa
        foreign key (email_destinatario, gruppo_da_cui_avvisato) references partecipante
            on delete cascade
);

alter table avvisa
    owner to postgres;

create table mi_piace
(
    id_contenuto       integer               not null
        constraint fk_id_contenuto
            references contenuto,
    titolo_gruppo      varchar(30)           not null,
    email_partecipante varchar(100)          not null,
    tipo_like          social_group.reazione not null,
    data               date                  not null,
    constraint pk_like
        primary key (id_contenuto, titolo_gruppo, email_partecipante),
    constraint fk_partecipante
        foreign key (titolo_gruppo, email_partecipante) references partecipante
);

alter table mi_piace
    owner to postgres;

create table segue
(
    email_utente1 varchar(100)
        constraint fk_email_utente1
            references utente
            on delete cascade,
    email_utente2 varchar(100)
        constraint fk_email_utente2
            references utente
            on delete cascade,
    constraint uq_segue
        unique (email_utente1, email_utente2)
);

alter table segue
    owner to postgres;

create function admin_partecipante() returns trigger
    language plpgsql
as
$$
    BEGIN
    INSERT INTO partecipante
        VALUES(new.data_Creazione,new.email_admin, new.titolo);
        return new;
    end;
$$;

alter function admin_partecipante() owner to postgres;

create trigger tr_admin_partecipante
    after insert
    on gruppo
    for each row
execute procedure admin_partecipante();

create function aggiorna_email_admin() returns trigger
    language plpgsql
as
$$
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

alter function aggiorna_email_admin() owner to postgres;

create trigger tr_aggiorna_email_admin
    after delete
    on partecipante
    for each row
execute procedure aggiorna_email_admin();

create function genera_notifica() returns trigger
    language plpgsql
as
$$

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

alter function genera_notifica() owner to postgres;

create trigger tr_genera_notifica
    after insert
    on contenuto
    for each row
execute procedure genera_notifica();

create function avvisa_utenti() returns trigger
    language plpgsql
as
$$
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

alter function avvisa_utenti() owner to postgres;

create trigger tr_avvisa_utenti
    after insert
    on notifica
    for each row
execute procedure avvisa_utenti();

create function elimina_gruppo_vuoto() returns trigger
    language plpgsql
as
$$
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

alter function elimina_gruppo_vuoto() owner to postgres;

create trigger tr_elimina_gruppo_vuoto
    after delete
    on partecipante
    for each row
execute procedure elimina_gruppo_vuoto();

create function verifica_commento() returns trigger
    language plpgsql
as
$$
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

alter function verifica_commento() owner to postgres;

create trigger tr_verifica_commento
    before insert
    on commento
    for each row
execute procedure verifica_commento();

create function verifica_mi_piace() returns trigger
    language plpgsql
as
$$
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

alter function verifica_mi_piace() owner to postgres;

create trigger tr_verifica_mi_piace
    before insert
    on mi_piace
    for each row
execute procedure verifica_mi_piace();

create function lunghezza_password() returns trigger
    language plpgsql
as
$$
BEGIN
    IF LENGTH(NEW.password) < 8 THEN
        RAISE EXCEPTION 'La password deve essere lunga almeno 8 caratteri';
    END IF;
    RETURN NEW;
END;
$$;

alter function lunghezza_password() owner to postgres;

create trigger password_length_trigger
    before insert
    on utente
    for each row
execute procedure lunghezza_password();

create function date_coerenti() returns trigger
    language plpgsql
as
$$
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

alter function date_coerenti() owner to postgres;

create trigger tr_date_coerenti
    before insert
    on commento
    for each row
execute procedure date_coerenti();

create function like_coerenti() returns trigger
    language plpgsql
as
$$
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

alter function like_coerenti() owner to postgres;

create trigger tr_like_coerenti
    before insert
    on mi_piace
    for each row
execute procedure like_coerenti();


