/*
Script para consumir API.
09/08/2024.
Allan Rodrigues. 

Neste pequeno projeto vamos consumir uma API da NASA, através de OLE Automation para verificar os asteroids proximos a terra em um determinado intervalo de datas.

Link API:
https://api.nasa.gov/
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

SET @APIEndPoint = N'https://api.nasa.gov/neo/rest/v1/neo/3542519?api_key=DEMO_KEY'
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
DROP TABLE IF EXISTS #AsteroidInfo
SELECT Nome, 
       Designacao, 
	   Magnitude, 
	   IIF(PotencialmentePerigoso = 1, 'Sim', 'Não') [É Potencialmente Perigoso?],
	   JSON_VALUE(DiametroEstimado,'$.kilometers.estimated_diameter_min') AS [Diametro Minimo em KM],
	   JSON_VALUE(DiametroEstimado,'$.kilometers.estimated_diameter_max') AS [Diametro Máximo em KM],
	   DataAproximacao, 
	   Orbita
INTO #AsteroidInfo FROM OPENJSON(@JSON) WITH (
                                                   Nome                    NVARCHAR(255) '$.name'
												  ,Designacao              NVARCHAR(500) '$.designation'
												  ,Magnitude               NVARCHAR(10)  '$.absolute_magnitude_h'
												  ,DiametroEstimado        NVARCHAR(MAX) '$.estimated_diameter' AS JSON
												  ,PotencialmentePerigoso  BIT           '$.is_potentially_hazardous_asteroid'
												  ,DadosDeAproximacao      NVARCHAR(MAX) '$.close_approach_data' AS JSON
												  )	AsteroidInfo
												  CROSS APPLY OPENJSON (AsteroidInfo.DadosDeAproximacao)
												  WITH (
												     DataAproximacao        DATE '$.close_approach_date'
												   , Orbita                 NVARCHAR(255) '$.orbiting_body'
												  ) as Orbitas
												  

SELECT *
FROM #AsteroidInfo