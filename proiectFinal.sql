
# 1. Se creeaza baza de date proiect. 
DROP DATABASE IF EXISTS proiect;
CREATE DATABASE proiect CHARSET=UTF8;
USE proiect;

# In cadrul sau se defineste procedura tabele() care sterge si recreeaza toate tabelele
DELIMITER $
CREATE PROCEDURE tabele() 
BEGIN
	SET foreign_key_checks = 0;
	DROP TABLE IF EXISTS Studenti, Profesori, Catalog, Tabela_veche;
    SET foreign_key_checks = 1;
    
    # Studenti - cu coloane pentru id(cheie primara), nume, prenume si index unic pentru p_nume si p_prenume
	CREATE TABLE Studenti (
		id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
		s_nume VARCHAR(50), 
		s_prenume VARCHAR(50), 
		UNIQUE (s_nume, s_prenume)
        )ENGINE=InnoDB;
        
	# Profesori - cu coloane pentru id(cheie primara), nume, prenume si index unic pentru p_nume si p_prenume
    CREATE TABLE Profesori (
		id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
		p_nume VARCHAR(50), 
        p_prenume VARCHAR(50),
		UNIQUE (p_nume, p_prenume)
        )ENGINE=InnoDB;
        
	# Catalog - cu coloane pentru id(cheie primara), data_ora, id_profesor, id_student, 
    # 			nota si chei externe pentru id_profesor si id_student
    CREATE TABLE Catalog (
		id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, 
		data_ora DATETIME,
        id_profesor INT,
        id_student INT,
		FOREIGN KEY (id_profesor) REFERENCES Profesori (id), 
		FOREIGN KEY (id_student) REFERENCES Studenti (id), 
		nota INT
		)ENGINE=InnoDB; 
        
	# Tabela_veche in care vor fi importate info din fisier.txt inainte de a fi distribute in tabelele finale
    # si coloana fulldate
    CREATE TABLE Tabela_veche (
		`date` VARCHAR(10), 
        `time` VARCHAR(8), 
        student_name VARCHAR(50), 
		student_surname VARCHAR(50), 
        professor_name VARCHAR(50), 
        professor_surname VARCHAR(50), 
        grade INT, 
		fulldate DATETIME
        )ENGINE=InnoDB;
END$
DELIMITER ;


# Se genereaza tabelele apeland functia tabele()
CALL tabele();


# 2. Se creaza o functie care va primi doi parametri de tip text (VARCHAR) si va formata data si ora din formatul 
# 	 regasit in fisier.txt in format corect MySQL;
DELIMITER $
CREATE FUNCTION reformatDateTime(`date` VARCHAR(10), `time` VARCHAR(8)) RETURNS DATETIME DETERMINISTIC 
COMMENT 'Functia formateaza data si ora din VARCHAR in DATETIME'
BEGIN
	DECLARE dateTimeFinal DATETIME;
    SET dateTimeFinal = CONCAT_WS('T', STR_TO_DATE(`date`, '%Y.%d.%m'), `time`);
    RETURN dateTimeFinal;
END$
DELIMITER ;


# 3. Se creaza un trigger before insert, pe Tabela_veche, care, la fiecare rand inserat in Tabela_veche 
# 	 va apela functia de formatare a datei definita anterior(reformatDateTime), cu parametrii data si ora 
# 	 care sunt introdusi in Tabela_veche si va popula coloana fulldate din aceeasi tabela
DELIMITER $
CREATE TRIGGER insertDateTime BEFORE INSERT ON Tabela_veche FOR EACH ROW
BEGIN
	DECLARE triggerFullDate DATETIME;
	SET triggerFullDate = reformatDateTime(new.`date`, new.`time`);
    SET new.fulldate = triggerFullDate;
END$
DELIMITER ;


# 4. Se importa datele din fisier.txt in Tabela_veche. Coloana fulldate va fi completata automat de trigger
LOAD DATA LOCAL INFILE '/Users/Tudor/Desktop/SQL/Proiect_MySQL/fisier.txt'
#LOAD DATA LOCAL INFILE 'C:/wt/nume_fisier.txt'
	INTO TABLE Tabela_veche
	FIELDS TERMINATED BY ';'
	ENCLOSED BY '\''
	LINES TERMINATED BY '\r\n'
	IGNORE 1 LINES
	(`date`, `time`, student_name, student_surname, professor_name, professor_surname, grade);
    
    
# 5. Se distribuie informatia din Tabela_veche in tabelele noi, deja create, astfel incat sa se mentina 
# 	 corelatia dintre informatii: 

# lista de nume unice de studenti din Tabela_veche se introduce in Studenti
INSERT INTO Studenti (s_nume, s_prenume) SELECT student_name, student_surname FROM Tabela_veche 
	ON DUPLICATE KEY UPDATE s_prenume=student_surname;

# lista de nume unice de profesori din Tabela_veche se introduce in Profesori
INSERT INTO Profesori (p_nume, p_prenume) SELECT professor_name, professor_surname FROM Tabela_veche 
	ON DUPLICATE KEY UPDATE p_prenume=professor_surname;

# se populeaza tabela Catalog pe baza Tabela_veche, Studenti si Profesori, prin „inlocuirea" numelor 
# de studenti si profesori cu id-urile corespunzatoare si a celorlalte informatii pentru data si nota
INSERT INTO Catalog (data_ora, nota) SELECT fulldate, grade FROM Tabela_veche;

# Se completeaza cheile externe aferente din celelalte table 
UPDATE Catalog JOIN Profesori JOIN Studenti JOIN Tabela_veche
	SET id_profesor=Profesori.id , 
		id_student=Studenti.id WHERE 
			(Tabela_veche.fulldate=Catalog.data_ora)
		AND (Tabela_veche.grade=Catalog.nota)
		AND	(Profesori.p_nume=Tabela_veche.professor_name)
        AND (Profesori.p_prenume=Tabela_veche.professor_surname)
		AND (Studenti.s_nume=Tabela_veche.student_name)
        AND (Studenti.s_prenume=Tabela_veche.student_surname);

# 6. Se creeaza o procedura rapoarte() care produce urmatoarele rapoarte: 
DELIMITER $
CREATE PROCEDURE rapoarte()
BEGIN

# lista cu mediile studentilor in anul 2017 ordonati dupa medie descrescator
SELECT CONCAT_WS(' ', Studenti.s_nume, Studenti.s_prenume) AS nume_prenume_student,
	AVG(Catalog.nota) AS medie_student_2017 FROM Studenti JOIN Catalog 
    ON (Catalog.id_student=Studenti.id) WHERE YEAR (Catalog.data_ora)=2017 
    GROUP BY nume_prenume_student 
    ORDER BY medie_student_2017 DESC, nume_prenume_student;


# studentul care are cele mai multe note (daca sunt mai multi primul in ordine alfabetica)
	# varianta in care afisam si cate note are studentul cu cele mai multe note
SELECT CONCAT_WS(' ', Studenti.s_nume, Studenti.s_prenume) AS nume_prenume_student_cele_mai_multe_note, 
	COUNT(Catalog.nota) AS numar_note_student FROM Studenti JOIN Catalog ON 
    (Catalog.id_student=Studenti.id) 
    GROUP BY nume_prenume_student_cele_mai_multe_note
    ORDER BY numar_note_student DESC, nume_prenume_student_cele_mai_multe_note LIMIT 1;

    # varianta in care afisam exclusiv numele studentului cu cele mai multe note
SELECT CONCAT_WS(' ', Studenti.s_nume, Studenti.s_prenume) AS nume_prenume_student_cele_mai_multe_note
	FROM Studenti JOIN Catalog ON (Catalog.id_student=Studenti.id) 
    WHERE (SELECT Studenti.id FROM Studenti JOIN Catalog ON (Catalog.id_student=Studenti.id) 
    GROUP BY Studenti.id ORDER BY COUNT(Catalog.nota) DESC, Studenti.s_nume, Studenti.s_prenume LIMIT 1)=Studenti.id
    ORDER BY nume_prenume_student_cele_mai_multe_note LIMIT 1;
    
    
# profesorul care a acordat cele mai multe note (daca sunt mai multi primul in ordine alfabetica)
	# varianta in care afisam si numarul de note date de profesorul care a acordat cele mai multe note
SELECT CONCAT_WS(' ', Profesori.p_nume, Profesori.p_prenume) AS nume_prenume_profesor_cele_mai_multe_note, 
	COUNT(Catalog.nota) AS numar_note_profesor FROM Profesori JOIN Catalog ON 
    (Catalog.id_profesor=Profesori.id) 
    GROUP BY nume_prenume_profesor_cele_mai_multe_note 
    ORDER BY numar_note_profesor DESC, nume_prenume_profesor_cele_mai_multe_note LIMIT 1;
    
    # varianta in care afisam exclusiv numele profesorului care a acordat cele mai multe note
SELECT CONCAT_WS(' ', Profesori.p_nume, Profesori.p_prenume) AS nume_prenume_profesor_cele_mai_multe_note
	FROM Profesori JOIN Catalog ON (Catalog.id_student=Profesori.id) 
    WHERE (SELECT Profesori.id FROM Profesori JOIN Catalog ON (Catalog.id_profesor=Profesori.id) 
    GROUP BY Profesori.id ORDER BY COUNT(Catalog.nota) DESC, Profesori.p_nume, Profesori.p_prenume LIMIT 1)=Profesori.id
    ORDER BY nume_prenume_profesor_cele_mai_multe_note LIMIT 1;


# profesorii care au acordat cel putin 3 note de 10(zece) in anul 2016 
	# varianta in care afisam si numarul de note de 10 acordate de profesori in 2016
SELECT CONCAT_WS(' ', Profesori.p_nume, Profesori.p_prenume) AS nume_prenume_profesor_cel_putin_trei_note_10_in_2016, 
	COUNT(Catalog.nota) AS numar_note_10_2016_profesor FROM Profesori JOIN Catalog ON 
    (Catalog.id_profesor=Profesori.id) WHERE YEAR (Catalog.data_ora)=2016 AND (Catalog.nota)=10
    GROUP BY nume_prenume_profesor_cel_putin_trei_note_10_in_2016 HAVING numar_note_10_2016_profesor>=3 
    ORDER BY numar_note_10_2016_profesor DESC;
    
	# varianta in care afisam exclusiv numele profesorilor care au acordat cel putin 3 note de 10 in 2016
SELECT CONCAT_WS(' ', Profesori.p_nume, Profesori.p_prenume) AS nume_prenume_profesor_cel_putin_trei_note_10_in_2016
	FROM Profesori JOIN Catalog ON (Catalog.id_profesor=Profesori.id) WHERE YEAR (Catalog.data_ora)=2016 AND 
    (Catalog.nota)=10 GROUP BY nume_prenume_profesor_cel_putin_trei_note_10_in_2016 
    HAVING (COUNT(Catalog.nota))>=3 ORDER BY (COUNT(Catalog.nota)) DESC;
    
    
# nume student, prenume student, nume profesor, prenume profesor, nota, data_ora pentru studentul care 
# a primit cele mai multe note
SELECT Studenti.s_nume AS `nume student cele mai multe note`, Studenti.s_prenume AS `prenume student`, 
	Profesori.p_nume AS `nume profesor`, Profesori.p_prenume AS `prenume profesor`, Catalog.nota, Catalog.data_ora 
    FROM Studenti JOIN Catalog ON (Catalog.id_student=Studenti.id) JOIN Profesori ON (Catalog.id_profesor=Profesori.id)
    WHERE (SELECT Studenti.id FROM Studenti JOIN Catalog ON (Catalog.id_student=Studenti.id) GROUP BY Studenti.id 
    ORDER BY COUNT(Catalog.nota) DESC, Studenti.s_nume, Studenti.s_prenume LIMIT 1)=Studenti.id 
    ORDER BY Catalog.data_ora DESC;
    
    
# media notelor date de fiecare profesor in parte in ordicea mediilor
SELECT CONCAT_WS(' ', Profesori.p_nume, Profesori.p_prenume) AS nume_prenume_profesor, 
	AVG(Catalog.nota) AS medie_note_profesor FROM Profesori JOIN Catalog ON 
    (Catalog.id_profesor=Profesori.id) 
    GROUP BY nume_prenume_profesor 
    ORDER BY medie_note_profesor DESC, nume_prenume_profesor;
    
END$
DELIMITER ;


# se genereaza rapoartele apeland procedura rapoarte()
CALL rapoarte();