/*
Trabalhando com PIVOT e UNPIVOT
09/08/2024
Allan Rodrigues
*/

--Criando um pivot, transformando as linhas de ano em colunas e agregando valores por produto
SELECT Name AS [Nome do Produto], 
       FORMAT(ISNULL([2011], 0.00),'c','pt-BR') AS [2011],  
	   FORMAT(ISNULL([2012], 0.00),'c','pt-BR') AS [2012],
	   FORMAT(ISNULL([2013], 0.00),'c','pt-BR') AS [2013],
	   FORMAT(ISNULL([2014], 0.00),'c','pt-BR') AS [2014]
FROM (
		SELECT DISTINCT 
			   YEAR(Orderdate) AS Ano,
			   P.[Name],
			   SUM(TotalDue) OVER Particao AS [Total]
		FROM Sales.SalesOrderHeader AS SOH
		  INNER JOIN Sales.SalesOrderDetail AS SOD ON SOH.SalesOrderID = SOD.SalesOrderID
		  INNER JOIN Production.Product     AS P ON P.ProductID = SOD.ProductID
		WINDOW Particao AS (
							PARTITION BY YEAR(OrderDate), P.[Name]
						   )
	 ) AS Origem
PIVOT
     ( 
	  SUM(Total)
	  FOR Ano IN ([2011],[2012],[2013],[2014])
	 )
	 AS PTable

/*
Criando um PIVOT dinâmico, a partir da consulta acima. 
*/
--
DECLARE @Colunas     NVARCHAR(MAX) = N''
       ,@PivotList   NVARCHAR(MAX) = N''
       ,@SqlCommand  NVARCHAR(MAX) = N''

-- Definimos o filtro a partir dessa primeira consulta para as colunas do pivot. A partir daqui os valores serão passados como parametro para o sql dinamico filtrando as colunas e tornando o pivot dinamico.
SELECT @Colunas += N',FORMAT(ISNULL([' + Ano + '], 0.00), ''c'',''pt-BR'') AS [' + Ano + ']'
      ,@PivotList += N',[' + Ano + ']'
   
FROM (
	SELECT DISTINCT CAST(YEAR(Orderdate) AS CHAR(04)) AS Ano -- É gerada uma tabela derivada com DISTINCT para evitar as repetições dos valores de Ano. 
	FROM Sales.SalesOrderHeader AS SOH
	WHERE OrderDate BETWEEN '2011-01-01' AND '2012-12-31'
	) as X

-- Construimos o SQL de forma dinamica para ser executado no comando EXEC, utilizando a função STUFF para deletar a string inicial e reinserir o restante da string com os valores de ANO, 
-- concatenados anteriormente
SET @SqlCommand = N'SELECT Name AS [Nome do Produto], 
                           ' + STUFF(@Colunas, 1, 1,'') + '  
        FROM (
		SELECT DISTINCT 
			   YEAR(Orderdate) AS Ano,
			   P.[Name],
			   SUM(TotalDue) OVER Particao AS [Total]
		FROM Sales.SalesOrderHeader AS SOH
		  INNER JOIN Sales.SalesOrderDetail AS SOD ON SOH.SalesOrderID = SOD.SalesOrderID
		  INNER JOIN Production.Product     AS P ON P.ProductID = SOD.ProductID
		WINDOW Particao AS (
							PARTITION BY YEAR(OrderDate), P.[Name]
						   )
	 ) AS Origem
       PIVOT
     ( 
	  SUM(Total)
	  FOR Ano IN ('+   STUFF(@PivotList,1,1,'')     +')
	 )
	 AS PTable'
EXECUTE sp_executesql @SqlCommand

DROP TABLE IF EXISTS #TmpUnpivot
CREATE TABLE #TmpUnpivot (NomeProduto VARCHAR(MAX), [2011] NVARCHAR(MAX), [2012] NVARCHAR(MAX))

INSERT INTO #TmpUnpivot (NomeProduto, [2011], [2012]) EXECUTE sp_executesql @SqlCommand


/*
  UNPIVOT de dados. Transformando colunas em linhas.
  Vamos usar os dados gerados anteriormente para reverter como linhas. 
*/
SELECT * FROM 
  (SELECT NomeProduto, [2011], [2012] FROM #TmpUnpivot) AS PTable
  UNPIVOT
  (Total FOR Ano IN ([2011],[2012])) AS Unpvt

