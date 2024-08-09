/*
Script para consumir API.
09/08/2024.
Allan Rodrigues. 

Neste pequeno projeto vamos consumir uma API de Pokemons, através de OLE Automation. 

Link API:
https://pokeapi.co/docs/v2#pokemon
*/

DECLARE @ObjectContext INT -- Variável de escopo local para receber o Token do objeto. Este token identifica o objeto OLE criado, e passado para as proximas procedures do contexto de execução. 
       ,@HResult      INT -- Captura o valor de retorno de execução da procedure, caso seja <> 0 então o processo retornou erro. 

-- Controle de erro
DECLARE @Source       VARCHAR(255)
       ,@Descr        VARCHAR(255)
--

-- 
DECLARE @APIEndPoint  NVARCHAR(MAX) -- Link do Endpoint da API
DECLARE @JSON         NVARCHAR(MAX)
DECLARE @PokeJson     NVARCHAR(MAX)
DECLARE @Dados        AS TABLE(Coluna_Json NVARCHAR(MAX)) -- Armazenar os dados em JSON

SET @APIEndPoint = N'https://pokeapi.co/api/v2/pokemon/?limit=100'
--
/*
  Bloco try que realiza o consumo da API 
*/
BEGIN TRY   
   -- Instancia o objeto OLE para consumir API
   EXEC @HResult = sp_OACreate 'MSXML2.ServerXMLHTTP.6.0', @ObjectContext OUT; 
   IF @HResult <> 0 
   BEGIN
      EXEC sp_OAGetErrorInfo @ObjectContext, @Source OUT, @Descr OUT
     ;THROW 50000,@Descr, 1;
   END

   -- prepara o envio da requisição GET para o Endpoint
   EXEC @HResult = sp_OAMethod @ObjectContext, 'OPEN', NULL, 'GET', @APIEndPoint, 'False'
   IF @HResult <> 0 
   BEGIN
      EXEC sp_OAGetErrorInfo @ObjectContext, @Source OUT, @Descr OUT
     ;THROW 50000,@Descr, 1;
   END

   -- envia a requisição para o endpoint
   EXEC @HResult = sp_OAMethod @ObjectContext, 'SEND' 
   IF @HResult <> 0 
   BEGIN
      EXEC sp_OAGetErrorInfo @ObjectContext, @Source OUT, @Descr OUT
     ;THROW 50000,@Descr, 1;
   END

   INSERT INTO @Dados EXEC sp_OAGetProperty @ObjectContext, 'ResponseText'
   SELECT @JSON = Coluna_Json FROM @Dados
END TRY 
BEGIN CATCH  
   ;THROW 
END CATCH

/*
 Tratamento dos dados em JSON
*/
DROP TABLE IF EXISTS #PokemonsAPIList 
SELECT * INTO #PokemonsAPIList FROM OPENJSON(@JSON) WITH (
                                                   [List] NVARCHAR(MAX) '$.results' AS JSON )													 
SELECT @PokeJson = [List] FROM #PokemonsAPIList

DROP TABLE IF EXISTS #Pokemons
SELECT * INTO #Pokemons FROM OPENJSON(@PokeJson) 
WITH (
      Nome  NVARCHAR(500) '$.name'
	 ,[url] NVARCHAR(MAX) '$.url'
)

SELECT * FROM #Pokemons
ORDER BY Nome 