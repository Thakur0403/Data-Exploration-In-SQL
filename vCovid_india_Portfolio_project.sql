/*
Covid 19 Data Exploration 

Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types

*/

Select *
From [Portfolio project]..CovidDeaths
Where continent is not null 
order by 3,4


-- Select Data that we are going to be starting with

Select Location, date, total_cases, new_cases, total_deaths, population
From [Portfolio project]..CovidDeaths
Where continent is not null 
order by 1,2


-- Total Cases vs Total Deaths
-- Shows likelihood of dying if you contract covid in your country
SELECT 
    Location, 
    date, 
    CAST(total_cases AS float) AS total_cases,  -- Assuming total_cases is a numeric column
    CAST(total_deaths AS float) AS total_deaths,  -- Assuming total_deaths is a numeric column
    CASE 
        WHEN total_cases = 0 THEN 0  -- To handle division by zero
        ELSE (CAST(total_deaths AS float) / CAST(total_cases AS float)) * 100
    END AS DeathPercentage
FROM [Portfolio project]..CovidDeaths
WHERE location like '%india%' and continent IS NOT NULL



-- Total Cases vs Population
-- Shows what percentage of population infected with Covid

Select Location, date, Population, total_cases,  (total_cases/population)*100 as PercentPopulationInfected
From [Portfolio project]..CovidDeaths
--Where location like '%india%'
order by 1,2


-- Countries with Highest Infection Rate compared to Population

SELECT Location,
       Population,
       MAX(TRY_CAST(total_cases AS DECIMAL(18, 2))) AS HighestInfectionCount,
       (MAX(TRY_CAST(total_cases AS DECIMAL(18, 2))) * 100.0) / NULLIF(TRY_CAST(Population AS DECIMAL(18, 2)), 0) AS PercentPopulationInfected
FROM [Portfolio project]..CovidDeaths
--WHERE Location LIKE '%india%'
GROUP BY Location, Population
ORDER BY PercentPopulationInfected DESC




-- Countries with Highest Death Count per Population

Select Location, MAX(cast(Total_deaths as int)) as TotalDeathCount
From [Portfolio project]..CovidDeaths
--Where location like '%india%'
Where continent is not null 
Group by Location
order by TotalDeathCount desc



-- BREAKING THINGS DOWN BY CONTINENT

-- Showing contintents with the highest death count per population

Select continent, MAX(cast(Total_deaths as int)) as TotalDeathCount
From [Portfolio project]..CovidDeaths
--Where location like '%india%'
Where continent is not null 
Group by continent
order by TotalDeathCount desc



-- GLOBAL NUMBERS

Select SUM(new_cases) as total_cases, SUM(cast(new_deaths as int)) as total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
From [Portfolio project]..CovidDeaths
--Where location like '%india%'
where continent is not null 
--Group By date
order by 1,2



-- Total Population vs Vaccinations
-- Shows Percentage of Population that has recieved at least one Covid Vaccine

SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated,
    CASE
        WHEN dea.population = 0 THEN 0  -- To handle cases where population is 0
        ELSE (SUM(CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) / dea.population) * 100
    END AS PercentPopulationVaccinated
FROM [Portfolio project]..CovidDeaths dea
JOIN [Portfolio project]..CovidVaccinations vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2, 3

-- Using CTE to perform Calculation on Partition By in previous query

WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
AS
(
    SELECT
        dea.continent,
        dea.location,
        dea.date,
        dea.population,
        vac.new_vaccinations,
        SUM(CONVERT(BIGINT, vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
    FROM
        [Portfolio project]..CovidDeaths dea
    JOIN
        [Portfolio project]..CovidVaccinations vac
        ON dea.location = vac.location
        AND dea.date = vac.date
    WHERE
        dea.continent IS NOT NULL
)
SELECT
    *,
    CASE
        WHEN Population = 0 THEN 0  -- Handle cases where population is 0
        ELSE (RollingPeopleVaccinated * 100.0 / Population)  -- Use 100.0 to ensure a floating-point division
    END AS PercentPopulationVaccinated
FROM
    PopvsVac



-- Using Temp Table to perform Calculation on Partition By in previous query

-- Drop the temporary table if it exists
IF OBJECT_ID('tempdb..#PercentPopulationVaccinated') IS NOT NULL
    DROP TABLE #PercentPopulationVaccinated;

-- Create the temporary table
CREATE TABLE #PercentPopulationVaccinated
(
    Continent NVARCHAR(255),
    Location NVARCHAR(255),
    Date DATETIME,
    Population NUMERIC, -- Use NUMERIC or FLOAT for population
    New_vaccinations NUMERIC, -- Use NUMERIC or FLOAT for new_vaccinations
    RollingPeopleVaccinated NUMERIC -- Use NUMERIC or FLOAT for RollingPeopleVaccinated
);

-- Insert data into the temporary table
INSERT INTO #PercentPopulationVaccinated
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(CONVERT(BIGINT, vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
FROM
    [Portfolio project]..CovidDeaths dea
JOIN
    [Portfolio project]..CovidVaccinations vac
    ON dea.location = vac.location
    AND dea.date = vac.date;

-- Select data from the temporary table
SELECT
    *,
    CASE
        WHEN Population = 0 THEN 0  -- Handle cases where population is 0
        ELSE (RollingPeopleVaccinated * 100.0 / Population)  -- Use 100.0 to ensure a floating-point division
    END AS PercentPopulationVaccinated
FROM
    #PercentPopulationVaccinated





-- Creating View to store data for later visualizations
-- Switch to the database
USE [Portfolio project];

-- Drop the existing view (if it exists)
IF OBJECT_ID('dbo.PercentPopulationVaccinated', 'V') IS NOT NULL
    DROP VIEW dbo.PercentPopulationVaccinated

-- Create the new view
CREATE VIEW dbo.PercentPopulationVaccinated AS
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(CONVERT(BIGINT, vac.new_vaccinations)) OVER (PARTITION BY dea.Location ORDER BY dea.location, dea.Date) AS RollingPeopleVaccinated
FROM
    [Portfolio project]..CovidDeaths dea
JOIN
    [Portfolio project]..CovidVaccinations vac
    ON dea.location = vac.location
    AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;
 

 select*
 from PercentPopulationVaccinated