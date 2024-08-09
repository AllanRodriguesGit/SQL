USE AdventureWorks2022
GO
/*
Usando Window Function é possível particionar e ordenar um conjunto de linhas. 
Utilizamos a cláusula OVER junto com as funções de agregações para criar Totais Correntes, Agregações Acumulativas etc. 

Quando agregamos um conjunto de linhas com Window Function não há necessidade de utilizar o GROUP BY, dessa forma o resultado apresentado pode conter visões analíticas e sintéticas.


A sintaxe básica pode ser: OVER ([PARTITION BY]
                                 [ORDER BY]
								 [ROW ou RANGE])

**Limitações:
  Não podemos usar a cláusula OVER com agregações contendo DISTINCT Ex: COUNT(DISTINCT Funcionarios)
  RANGE não pode ser utilizado com <Valor> PRECEDING ou <Valor> FOLLOWING



PARTITION BY 
  Cria partições no resultado da consulta. A análise com Window Function é aplicada para cada partição criada. 

ORDER BY 
  Ordena os dados dentro de cada partição
    
ROWS or RANGE
  Defini os pontos de inicio e fim dentro de cada partição


UNBOUNDED PRECEDING
  Defini o início da partição, quando estamos utilizando ROWS ou RANGE. UNBOUNDED PRECEDING pode ser utilizado APENAS no início do intervalo. 
  Podemos substituir UNBOUNDED por um valor, no qual identificará a linha de início baseado na linha atual. 

CURRENT ROW 
  Defini a linha atual como o início ou fim da partição quando usando com ROWS. 
  CURRENT ROW pode usado tanto para especificar tanto o início quanto o fim de uma partição. 

BETWEEN AND 
  Pode ser usado com ROWS ou RANGE para definir o início e o fim de uma partição. 

UNBOUNDED FOLLOWING 
  Defini que o conjunto de linhas (window) terminará na ultima linha da partição. 
  UNBOUNDED FOLLOWING pode ser utilizado APENAS como ponto de final de um conjunto de linhas (window)
  É possível substituir UNBOUNDED por um valor, que será o início da partição ou o fim da partição a partir da linha atual. 
*/


-- Aplicando a cláusula OVER
-- Vamos gerar um valor de número da linha utilizando window function. 
/*
  Perceba que não será criado uma partição. Então a cláusula OVER aplicará o ROW_NUMBER() a todo nosso resultado, porém é necessário uma ordenação para que a sequencia de linhas seja criada
*/
SELECT 
      ROW_NUMBER() OVER (ORDER BY ProductID) AS Sequencial
	 ,*
FROM Production.Product

/*
  Aplicando a mesma consulta porém em partições podemos criar subconjuntos sequenciais. 
*/
SELECT 
      ROW_NUMBER() OVER (PARTITION BY Color ORDER BY ProductID) AS Sequencial
	 ,*
FROM Production.Product


/*
  A cláusula over também pode ser utilizada sem argumentos OVER () , com isso será considerado o total do seu resultado sem partição e sem ordenação. 
  Geralmente utilizado para gerar totais. 
  Observe que não usamos group by para gerar essa agreção. As linhas em detalhes são matidas e o valor então se repete para o conjunto como um todo.
*/
SELECT 
  SUM(TotalDue) OVER () [Total de Pedidos para o Ano de 2014] 
,* FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2014-01-01' AND OrderDate < '2015-01-01'

/*
 Agregando os dados utilizando a partição de ano. 
*/
SELECT DISTINCT 
       YEAR(Orderdate) AS Ano,
	   SUM(TotalDue) OVER (PARTITION BY YEAR(OrderDate)) [Total Por Ano]
FROM Sales.SalesOrderHeader
ORDER BY Ano

/*
Agregando dados por mais de um nível de partição e agregando em níveis diferentes.
Possibilitando diferentes visões com a mesma consulta.
*/
SELECT DISTINCT 
       YEAR(Orderdate) AS Ano,
	   MONTH(OrderDate) AS [Mês],
	   SUM(TotalDue) OVER (PARTITION BY YEAR(OrderDate),MONTH(OrderDate)) [Total Por Mes],
	   SUM(TotalDue) OVER (PARTITION BY YEAR(OrderDate)) [Total Por Ano]
FROM Sales.SalesOrderHeader
ORDER BY Ano, [Mês]

/*
Gerando um total corrent por Ano. 
*/
SELECT DISTINCT 
       YEAR(Orderdate) AS Ano,
	   SUM(TotalDue) OVER (PARTITION BY YEAR(OrderDate)) [Total Por Ano],
	   SUM(TotalDue) OVER  (
	                        ORDER BY YEAR(OrderDate) -- Ordenamos os dados dentro da partição				
	                       ) [Total Corrente]
FROM Sales.SalesOrderHeader
ORDER BY Ano

/*
Geral total corrente por partições.
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
	  -- Utilizamos o UNBOUNDED PRECEDING para iniciar a soma desde o primeiro valor da partição até a linha corrente CURRENT ROW
	  ,SUM(UnitPrice * OrderQty) OVER (PARTITION BY SOD.SalesOrderID ORDER BY ProductID RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS [Total Acumulado com RANGE]
	  -- Podemos especificar a quantidade de linhas envolvidas na agregação até a linha corrente. Neste caso está somando a linha corrente com o o valor da linha anterior
	  -- dessa forma é possível movimentar as "fronteiras" dos valores que serão utilizados para a agregação.
	  ,SUM(UnitPrice * OrderQty) OVER (PARTITION BY SOD.SalesOrderID ORDER BY ProductID ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) AS [Total = Valor Atual + Valor Anterior]
	  ,MIN(UnitPrice * OrderQty) OVER (PARTITION BY SOD.SalesOrderID) AS [Menor Valor Calculado da Partição]
	  ,Max(UnitPrice * OrderQty) OVER (PARTITION BY SOD.SalesOrderID) AS [Maior Valor Calculado da Partição]
	  ,SOH.SubTotal
FROM Sales.SalesOrderHeader AS SOH
INNER JOIN Sales.SalesOrderDetail AS SOD ON SOH.SalesOrderID = SOD.SalesOrderID
WHERE SOD.SalesOrderID = 43661
ORDER BY SOD.SalesOrderID, SOD.ProductID 


/*
Tendo uma visão sobre o conjunto de dados por ano. 
*/
SELECT DISTINCT
   YEAR(SOH.DueDate)       AS [Ano do pedido]
  ,AVG(SOH.Subtotal)       OVER (PARTITION BY YEAR(SOH.DueDate)) AS [Média Por Ano]
  ,MAX(SOH.Subtotal)       OVER (PARTITION BY YEAR(SOH.DueDate)) AS [Maior Valor do Ano]
  ,MIN(SOH.Subtotal)       OVER (PARTITION BY YEAR(SOH.DueDate)) AS [Menor Valor do Ano]
  ,COUNT(SOH.SalesOrderID) OVER (PARTITION BY YEAR(SOH.DueDate)) AS [Total de Pedidos por Ano]
  ,SUM(SOH.SalesOrderID)   OVER (PARTITION BY YEAR(SOH.DueDate)) AS [Valor Total de Pedidos por Ano]
  ,STDEV(SOH.Subtotal)     OVER (PARTITION BY YEAR(SOH.DueDate)) AS [Desvio Padrão por Ano]
FROM Sales.SalesOrderHeader AS SOH
ORDER BY [Ano do pedido]

/*
Calculando Média Movel por Ano/Mes
*/
SELECT DISTINCT
   YEAR(SOH.DueDate)       AS [Ano]
  ,MONTH(SOH.DueDate)      AS [Mês]
  ,AVG(SOH.Subtotal)       OVER (PARTITION BY YEAR(SOH.DueDate),MONTH(SOH.DueDate) 
                                 ORDER BY YEAR(SOH.DueDate),MONTH(SOH.DueDate) 
								 ) AS [Média Movel por Ano/Mes]
FROM Sales.SalesOrderHeader AS SOH
ORDER BY [Ano], [Mês]


/*
  Checando o primeiro e o ultimo valor de uma partição. 
*/
SELECT DISTINCT 
       ST.Name, 
       FIRST_VALUE(SOH.OrderDate) OVER (PARTITION BY ST.Name ORDER BY SOH.OrderDate) AS [Primeira Data de Pedido],
	   -- Para chegar até o ultimo valor é necessario ordernar o subconjunto de linhas e então limitar o início e o fim da fronteira dos dados. 
	   LAST_VALUE(SOH.OrderDate)  OVER (PARTITION BY ST.Name ORDER BY SOH.OrderDate
	                                    RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS [Ultima Data de Pedido]
FROM Sales.SalesOrderHeader AS SOH
  INNER JOIN Sales.SalesTerritory    AS ST ON SOH.TerritoryID = ST.TerritoryID


/*
  Usando a função LEAD para retorno o valor da proxima linha. 
*/
SELECT 
 Description AS [Descrição], 
 DiscountPct AS [Pct_Desconto],
 LEAD(DiscountPct) OVER (ORDER BY SpecialOfferID) AS [Proximo Desconto]
FROM Sales.SpecialOffer
WHERE DiscountPct > 0
ORDER BY SpecialOfferID 


/*
 Usando a função LAG para retornar o valor anterior 
*/
SELECT DISTINCT
       SOD.ProductID
      ,SOH.DueDate
	  ,LAG(SOH.DueDate) OVER (PARTITION BY SOD.ProductID ORDER BY SOH.DueDate) AS [Data Pedido Anterior]
FROM Sales.SalesOrderHeader AS SOH
INNER JOIN Sales.SalesOrderDetail AS SOD ON SOH.SalesOrderID = SOD.SalesOrderID
WHERE ProductID = 905



/*
 ** A PARTIR DA VERSÃO SQL SERVER 2022
 Utilizando a clásula WINDOW 
*/
ALTER DATABASE AdventureWorks2022
SET COMPATIBILITY_LEVEL = 160;

SELECT DISTINCT
   YEAR(SOH.DueDate)       AS [Ano do pedido]
  ,AVG(SOH.Subtotal)       OVER Ano_DataPedido AS [Média Por Ano]
  ,MAX(SOH.Subtotal)       OVER Ano_DataPedido AS [Maior Valor do Ano]
  ,MIN(SOH.Subtotal)       OVER Ano_DataPedido AS [Menor Valor do Ano]
  ,COUNT(SOH.SalesOrderID) OVER Ano_DataPedido AS [Total de Pedidos por Ano]
  ,SUM(SOH.SalesOrderID)   OVER Ano_DataPedido AS [Valor Total de Pedidos por Ano]
  ,STDEV(SOH.Subtotal)     OVER Ano_DataPedido AS [Desvio Padrão por Ano]
FROM Sales.SalesOrderHeader AS SOH
		WINDOW Ano_DataPedido AS (PARTITION BY YEAR(SOH.DueDate))
ORDER BY [Ano do pedido]

/*
 Definindo mais de uma cláusula window
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










