USE AdventureWorks2022
GO
/*
Usando Window Function � poss�vel particionar e ordenar um conjunto de linhas. 
Utilizamos a cl�usula OVER junto com as fun��es de agrega��es para criar Totais Correntes, Agrega��es Acumulativas etc. 

Quando agregamos um conjunto de linhas com Window Function n�o h� necessidade de utilizar o GROUP BY, dessa forma o resultado apresentado pode conter vis�es anal�ticas e sint�ticas.


A sintaxe b�sica pode ser: OVER ([PARTITION BY]
                                 [ORDER BY]
								 [ROW ou RANGE])

**Limita��es:
  N�o podemos usar a cl�usula OVER com agrega��es contendo DISTINCT Ex: COUNT(DISTINCT Funcionarios)
  RANGE n�o pode ser utilizado com <Valor> PRECEDING ou <Valor> FOLLOWING



PARTITION BY 
  Cria parti��es no resultado da consulta. A an�lise com Window Function � aplicada para cada parti��o criada. 

ORDER BY 
  Ordena os dados dentro de cada parti��o
    
ROWS or RANGE
  Defini os pontos de inicio e fim dentro de cada parti��o


UNBOUNDED PRECEDING
  Defini o in�cio da parti��o, quando estamos utilizando ROWS ou RANGE. UNBOUNDED PRECEDING pode ser utilizado APENAS no in�cio do intervalo. 
  Podemos substituir UNBOUNDED por um valor, no qual identificar� a linha de in�cio baseado na linha atual. 

CURRENT ROW 
  Defini a linha atual como o in�cio ou fim da parti��o quando usando com ROWS. 
  CURRENT ROW pode usado tanto para especificar tanto o in�cio quanto o fim de uma parti��o. 

BETWEEN AND 
  Pode ser usado com ROWS ou RANGE para definir o in�cio e o fim de uma parti��o. 

UNBOUNDED FOLLOWING 
  Defini que o conjunto de linhas (window) terminar� na ultima linha da parti��o. 
  UNBOUNDED FOLLOWING pode ser utilizado APENAS como ponto de final de um conjunto de linhas (window)
  � poss�vel substituir UNBOUNDED por um valor, que ser� o in�cio da parti��o ou o fim da parti��o a partir da linha atual. 
*/


-- Aplicando a cl�usula OVER
-- Vamos gerar um valor de n�mero da linha utilizando window function. 
/*
  Perceba que n�o ser� criado uma parti��o. Ent�o a cl�usula OVER aplicar� o ROW_NUMBER() a todo nosso resultado, por�m � necess�rio uma ordena��o para que a sequencia de linhas seja criada
*/
SELECT 
      ROW_NUMBER() OVER (ORDER BY ProductID) AS Sequencial
	 ,*
FROM Production.Product

/*
  Aplicando a mesma consulta por�m em parti��es podemos criar subconjuntos sequenciais. 
*/
SELECT 
      ROW_NUMBER() OVER (PARTITION BY Color ORDER BY ProductID) AS Sequencial
	 ,*
FROM Production.Product


/*
  A cl�usula over tamb�m pode ser utilizada sem argumentos OVER () , com isso ser� considerado o total do seu resultado sem parti��o e sem ordena��o. 
  Geralmente utilizado para gerar totais. 
  Observe que n�o usamos group by para gerar essa agre��o. As linhas em detalhes s�o matidas e o valor ent�o se repete para o conjunto como um todo.
*/
SELECT 
  SUM(TotalDue) OVER () [Total de Pedidos para o Ano de 2014] 
,* FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2014-01-01' AND OrderDate < '2015-01-01'

/*
 Agregando os dados utilizando a parti��o de ano. 
*/
SELECT DISTINCT 
       YEAR(Orderdate) AS Ano,
	   SUM(TotalDue) OVER (PARTITION BY YEAR(OrderDate)) [Total Por Ano]
FROM Sales.SalesOrderHeader
ORDER BY Ano

/*
Agregando dados por mais de um n�vel de parti��o e agregando em n�veis diferentes.
Possibilitando diferentes vis�es com a mesma consulta.
*/
SELECT DISTINCT 
       YEAR(Orderdate) AS Ano,
	   MONTH(OrderDate) AS [M�s],
	   SUM(TotalDue) OVER (PARTITION BY YEAR(OrderDate),MONTH(OrderDate)) [Total Por Mes],
	   SUM(TotalDue) OVER (PARTITION BY YEAR(OrderDate)) [Total Por Ano]
FROM Sales.SalesOrderHeader
ORDER BY Ano, [M�s]

/*
Gerando um total corrent por Ano. 
*/
SELECT DISTINCT 
       YEAR(Orderdate) AS Ano,
	   SUM(TotalDue) OVER (PARTITION BY YEAR(OrderDate)) [Total Por Ano],
	   SUM(TotalDue) OVER  (
	                        ORDER BY YEAR(OrderDate) -- Ordenamos os dados dentro da parti��o				
	                       ) [Total Corrente]
FROM Sales.SalesOrderHeader
ORDER BY Ano

/*
Geral total corrente por parti��es.
*/
SELECT SOD.SalesOrderID
      ,SOD.ProductID
	  ,SOD.UnitPrice
	  ,OrderQty
	  ,SUM(UnitPrice * OrderQty) OVER (PARTITION BY SOD.SalesOrderID ORDER BY ProductID) AS [Total Acumulado]
	  ,SOH.SubTotal
FROM Sales.SalesOrderHeader AS SOH
INNER JOIN Sales.SalesOrderDetail AS SOD ON SOH.SalesOrderID = SOD.SalesOrderID
ORDER BY SOD.SalesOrderID, SOD.ProductID ASC

 SELECT 
       ROW_NUMBER() OVER (PARTITION BY SOD.SalesOrderID ORDER BY SOD.ProductID) AS Sequencial
	  ,SOD.SalesOrderID
      ,SOD.ProductID
	  ,SOD.UnitPrice
	  ,OrderQty
	  ,SUM(UnitPrice * OrderQty) OVER (PARTITION BY SOD.SalesOrderID ORDER BY ProductID) AS [Total Acumulado]
	  -- Utilizamos o UNBOUNDED PRECEDING para iniciar a soma desde o primeiro valor da parti��o at� a linha corrente CURRENT ROW
	  ,SUM(UnitPrice * OrderQty) OVER (PARTITION BY SOD.SalesOrderID ORDER BY ProductID RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS [Total Acumulado com RANGE]
	  -- Podemos especificar a quantidade de linhas envolvidas na agrega��o at� a linha corrente. Neste caso est� somando a linha corrente com o o valor da linha anterior
	  -- dessa forma � poss�vel movimentar as "fronteiras" dos valores que ser�o utilizados para a agrega��o.
	  ,SUM(UnitPrice * OrderQty) OVER (PARTITION BY SOD.SalesOrderID ORDER BY ProductID ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) AS [Total = Valor Atual + Valor Anterior]
	  ,MIN(UnitPrice * OrderQty) OVER (PARTITION BY SOD.SalesOrderID) AS [Menor Valor Calculado da Parti��o]
	  ,Max(UnitPrice * OrderQty) OVER (PARTITION BY SOD.SalesOrderID) AS [Maior Valor Calculado da Parti��o]
	  ,SOH.SubTotal
FROM Sales.SalesOrderHeader AS SOH
INNER JOIN Sales.SalesOrderDetail AS SOD ON SOH.SalesOrderID = SOD.SalesOrderID
WHERE SOD.SalesOrderID = 43661
ORDER BY SOD.SalesOrderID, SOD.ProductID 


/*
Tendo uma vis�o sobre o conjunto de dados por ano. 
*/
SELECT DISTINCT
   YEAR(SOH.DueDate)       AS [Ano do pedido]
  ,AVG(SOH.Subtotal)       OVER (PARTITION BY YEAR(SOH.DueDate)) AS [M�dia Por Ano]
  ,MAX(SOH.Subtotal)       OVER (PARTITION BY YEAR(SOH.DueDate)) AS [Maior Valor do Ano]
  ,MIN(SOH.Subtotal)       OVER (PARTITION BY YEAR(SOH.DueDate)) AS [Menor Valor do Ano]
  ,COUNT(SOH.SalesOrderID) OVER (PARTITION BY YEAR(SOH.DueDate)) AS [Total de Pedidos por Ano]
  ,SUM(SOH.SalesOrderID)   OVER (PARTITION BY YEAR(SOH.DueDate)) AS [Valor Total de Pedidos por Ano]
  ,STDEV(SOH.Subtotal)     OVER (PARTITION BY YEAR(SOH.DueDate)) AS [Desvio Padr�o por Ano]
FROM Sales.SalesOrderHeader AS SOH
ORDER BY [Ano do pedido]

/*
Calculando M�dia Movel por Ano/Mes
*/
SELECT DISTINCT
   YEAR(SOH.DueDate)       AS [Ano]
  ,MONTH(SOH.DueDate)      AS [M�s]
  ,AVG(SOH.Subtotal)       OVER (PARTITION BY YEAR(SOH.DueDate),MONTH(SOH.DueDate) 
                                 ORDER BY YEAR(SOH.DueDate),MONTH(SOH.DueDate) 
								 ) AS [M�dia Movel por Ano/Mes]
FROM Sales.SalesOrderHeader AS SOH
ORDER BY [Ano], [M�s]


/*
  Checando o primeiro e o ultimo valor de uma parti��o. 
*/
SELECT DISTINCT 
       ST.Name, 
       FIRST_VALUE(SOH.OrderDate) OVER (PARTITION BY ST.Name ORDER BY SOH.OrderDate) AS [Primeira Data de Pedido],
	   -- Para chegar at� o ultimo valor � necessario ordernar o subconjunto de linhas e ent�o limitar o in�cio e o fim da fronteira dos dados. 
	   LAST_VALUE(SOH.OrderDate)  OVER (PARTITION BY ST.Name ORDER BY SOH.OrderDate
	                                    RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS [Ultima Data de Pedido]
FROM Sales.SalesOrderHeader AS SOH
  INNER JOIN Sales.SalesTerritory    AS ST ON SOH.TerritoryID = ST.TerritoryID


/*
  Usando a fun��o LEAD para retorno o valor da proxima linha. 
*/
SELECT 
 Description AS [Descri��o], 
 DiscountPct AS [Pct_Desconto],
 LEAD(DiscountPct) OVER (ORDER BY SpecialOfferID) AS [Proximo Desconto]
FROM Sales.SpecialOffer
WHERE DiscountPct > 0
ORDER BY SpecialOfferID 


/*
 Usando a fun��o LAG para retornar o valor anterior 
*/
SELECT DISTINCT
       SOD.ProductID
      ,SOH.DueDate
	  ,LAG(SOH.DueDate) OVER (PARTITION BY SOD.ProductID ORDER BY SOH.DueDate) AS [Data Pedido Anterior]
FROM Sales.SalesOrderHeader AS SOH
INNER JOIN Sales.SalesOrderDetail AS SOD ON SOH.SalesOrderID = SOD.SalesOrderID
WHERE ProductID = 905



/*
 ** A PARTIR DA VERS�O SQL SERVER 2022
 Utilizando a cl�sula WINDOW 
*/
ALTER DATABASE AdventureWorks2022
SET COMPATIBILITY_LEVEL = 160;

SELECT DISTINCT
   YEAR(SOH.DueDate)       AS [Ano do pedido]
  ,AVG(SOH.Subtotal)       OVER Ano_DataPedido AS [M�dia Por Ano]
  ,MAX(SOH.Subtotal)       OVER Ano_DataPedido AS [Maior Valor do Ano]
  ,MIN(SOH.Subtotal)       OVER Ano_DataPedido AS [Menor Valor do Ano]
  ,COUNT(SOH.SalesOrderID) OVER Ano_DataPedido AS [Total de Pedidos por Ano]
  ,SUM(SOH.SalesOrderID)   OVER Ano_DataPedido AS [Valor Total de Pedidos por Ano]
  ,STDEV(SOH.Subtotal)     OVER Ano_DataPedido AS [Desvio Padr�o por Ano]
FROM Sales.SalesOrderHeader AS SOH
		WINDOW Ano_DataPedido AS (PARTITION BY YEAR(SOH.DueDate))
ORDER BY [Ano do pedido]

/*
 Definindo mais de uma cl�usula window
*/
SELECT DISTINCT 
       ST.Name, 
       FIRST_VALUE(SOH.OrderDate) OVER  Win AS [Primeira Data de Pedido],
	   LAST_VALUE(SOH.OrderDate)  OVER (Win
	                                    RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS [Ultima Data de Pedido]
FROM Sales.SalesOrderHeader AS SOH
  INNER JOIN Sales.SalesTerritory    AS ST ON SOH.TerritoryID = ST.TerritoryID
WINDOW Win       AS (Ordenacao),
       Particao  AS (PARTITION BY ST.Name),
       Ordenacao AS (Particao ORDER BY SOH.OrderDate);










