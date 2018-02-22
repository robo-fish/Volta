/**
This file is part of the Volta project.
Copyright (C) 2007-2013 Kai Berk Oezer
https://robo.fish/wiki/index.php?title=Volta
https://github.com/robo-fish/Volta

Volta is free software. You can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#import "FXSpiceOutputParser.h"
#import "FXComplexNumber.h"
#import "FXString.h"

static FXString const skCircuitHeaderStart = "Circuit: ";
static FXString const skNumDataRowsString = "No. of Data Rows : ";
static FXString const skDataTableIndexString = "Index ";
static FXString const skDashes = "--------------------------------------------------";
static FXString const skAnalysisTypeString_Transient = "Transient Analysis ";
static FXString const skAnalysisTypeString_AC = "AC Analysis ";
static FXString const skAnalysisTypeString_DC = "DC Analysis ";
static FXString const skAnalysisTypeString_DC_TRANS = "DC transfer characteristic ";
static FXString const skSPICEDataTableCellDelimiter = "\t";

static FXStringVector extractEntityTitles( FXString const & entityLine )
{
  FXStringVector entityTitles = entityLine.substring(skDataTableIndexString.length()).tokenize();
  return entityTitles;
}


static void addEntitiesToAnalysisData( VoltaPTAnalysisData & analysisData, FXStringVector const & entityTitles )
{
  for ( FXString entityTitleToBeAdded : entityTitles )
  {
    entityTitleToBeAdded.trimWhitespace();
    bool entityTitleExists = false;
    for ( VoltaPTEntityDataPtr entityData : analysisData.entities )
    {
      if ( entityData->title == entityTitleToBeAdded )
      {
        entityTitleExists = true;
        break;
      }
    }
    if ( !entityTitleExists )
    {
      VoltaPTEntityDataPtr entityData( new VoltaPTEntityData );
      entityData->title = entityTitleToBeAdded;
      analysisData.entities.push_back(entityData);
    }
  }
}


static FXString extractAnalysisTitle( FXString titleLine )
{
  return titleLine.trimWhitespace();
}


static VoltaPTAnalysisType extractAnalysisType( FXString line )
{
  VoltaPTAnalysisType result = VoltaPTAnalysisType::Unknown;
  line.trimWhitespace();
  if ( line.startsWith(skAnalysisTypeString_Transient) )
  {
    result = VoltaPTAnalysisType::Transient;
  }
  else if ( line.startsWith(skAnalysisTypeString_AC) )
  {
    result = VoltaPTAnalysisType::AC;
  }
  else if ( line.startsWith(skAnalysisTypeString_DC) )
  {
    result = VoltaPTAnalysisType::DC;
  }
  else if ( line.startsWith(skAnalysisTypeString_DC_TRANS) )
  {
    result = VoltaPTAnalysisType::DC_TRANS;
  }
  return result;
}


static std::vector<FXComplexNumber> extractEntityValuesFromTokens(FXStringVector const & tokens)
{
  std::vector<FXComplexNumber> result;
  if ( tokens.size() > 1 )
  {
    for ( size_t currentTokenIndex = 1; currentTokenIndex < tokens.size(); currentTokenIndex++ )
    {
      FXString token = tokens.at(currentTokenIndex);
      token.trimWhitespace();

      // Complex numbers are represented by two float values separated by a comma in addition to whitespace.
      FXComplexNumber value;
      int separatorLocation = token.find(",");
      if ( separatorLocation < 0 )
      {
        try
        {
          value = FXComplexNumber(token.extractFloat());
        }
        catch (std::exception & e)
        {
          DebugLog(@"Could not extract floating point value from string \"%@\".", token.cfString());
          continue;
        }
      }
      else if ( separatorLocation == token.length() - 1 )
      {
        try
        {
          float realPart = token.substring(0,separatorLocation).extractFloat();
          FXString imaginaryPartToken = tokens.at(currentTokenIndex+1);
          float imaginaryPart = imaginaryPartToken.extractFloat();
          value = FXComplexNumber( realPart, imaginaryPart );
          currentTokenIndex++;
        }
        catch (std::exception & e)
        {
          DebugLog(@"Could not extract floating point values of complex number components (%@ %@).", token.cfString(), tokens.at(currentTokenIndex+1).cfString());
        }
      }
      else
      {
        DebugLog( @"Encountered comma at an unexpected location in value string \"%@\".", token.cfString() );
      }

      result.push_back(value);
    }
  }
  return result;
}


enum class FXSpiceOutputParsingMode
{
  LookingForCircuit,
  LookingForAnalysis,
  LookingForTableData
};


static FXSpiceOutputParsingMode processLine_LookingForCircuit(FXStringVector const & lines, size_t & lineIndex, VoltaPTSimulationDataPtr simData)
{
  FXSpiceOutputParsingMode result = FXSpiceOutputParsingMode::LookingForCircuit;
  if ( lineIndex < lines.size() )
  {
    FXString line = lines.at(lineIndex);
    line.trimWhitespace();
    if ( line.startsWith(skCircuitHeaderStart) )
    {
      simData->title = line.substring(skCircuitHeaderStart.length()).trim();
      result = FXSpiceOutputParsingMode::LookingForAnalysis;
    }
  }
  lineIndex++;
  return result;
}


static FXSpiceOutputParsingMode processLine_LookingForAnalysis(FXStringVector const & lines, size_t & lineIndex, VoltaPTSimulationDataPtr simData)
{
  FXSpiceOutputParsingMode result = FXSpiceOutputParsingMode::LookingForAnalysis;
  if ( lineIndex < lines.size() )
  {
    FXString const & line = lines.at(lineIndex);
    VoltaPTAnalysisType const analysisType = extractAnalysisType(line);
    if ( analysisType != VoltaPTAnalysisType::Unknown )
    {
      FXString const & nextLine = lines.at(lineIndex + 1);
      if ( nextLine.startsWith(skDashes) )
      {
        VoltaPTAnalysisData analysisData;
        analysisData.title = extractAnalysisTitle(line);
        analysisData.type = analysisType;
        simData->analyses.push_back(analysisData);
        lineIndex++;
      }
    }
    else if ( line.startsWith(skDataTableIndexString) )
    {
      if ( !simData->analyses.empty() )
      {
        VoltaPTAnalysisData & lastAddedAnalysisData = simData->analyses.back();
        FXStringVector entityTitles = extractEntityTitles(line);
        addEntitiesToAnalysisData(lastAddedAnalysisData, entityTitles);
        result = FXSpiceOutputParsingMode::LookingForTableData;
      }
    }
  }
  lineIndex++;
  return result;
}


static FXSpiceOutputParsingMode processLine_LookingForTableData(FXStringVector const & lines, size_t & lineIndex, VoltaPTSimulationDataPtr simData)
{
  FXSpiceOutputParsingMode result = FXSpiceOutputParsingMode::LookingForTableData;
  if ( lineIndex < lines.size() )
  {
    FXString line = lines.at(lineIndex);
    line.trimWhitespace();
    if ( line.empty() )
    {
      result = FXSpiceOutputParsingMode::LookingForAnalysis;
    }
    else if ( !line.startsWith(skDashes) )
    {
      FXStringVector dataRowTokens = line.tokenize(skSPICEDataTableCellDelimiter);
      try
      {
        // The remaining tokens are values to be assigned to the entities.
        if ( simData->analyses.empty() )
        {
          DebugLog( @"Huh!!!??? This is impossible. In %s", __FILE__ );
        }
        else
        {
          VoltaPTAnalysisData& analysisData = simData->analyses.back();
          long const currentTableRowIndex = dataRowTokens.at(0).trimWhitespace().extractLong();
          if ( currentTableRowIndex != analysisData.entities.front()->samples.size() )
          {
            DebugLog(@"Unexpected table row index at line #%d.", (int)lineIndex);
            result = FXSpiceOutputParsingMode::LookingForAnalysis;
          }
          else
          {
            if ( (dataRowTokens.size() - 1) < simData->analyses.back().entities.size() )
            {
              DebugLog( @"The number of entity value tokens (%d) in the table row at line #%d (%@) is less than the number of entities.", (int)dataRowTokens.size() - 1, (int)lineIndex, line.cfString() );
            }
            else
            {
              std::vector<FXComplexNumber> entityValues = extractEntityValuesFromTokens( dataRowTokens );
              if ( entityValues.size() == analysisData.entities.size() )
              {
                analysisData.addEntityValues(entityValues);
              }
              else
              {
                DebugLog(@"The number of extracted values from table row at line #%d does not match the number of entities.", (int)lineIndex);
              }
            }
          }
        }
      }
      catch (std::runtime_error& e)
      {
        DebugLog(@"Error while attempting to parse table row at line #%d with contents \"%@\"", (int)lineIndex, line.cfString());
      }
    }
  }
  lineIndex++;
  return result;
}


// The output of the SPICE "print" command produces text data in table form.
//
// The table for an analysis type starts with a line containing the name of the analysis.
// This line is followed by a line with dashes.
// Then comes the table header with the names of the columns.
// The first column is the "Index" column with the running index of the current data set.
// Then comes the name of the X-axis (abscissa) variable
//     "time" for transient analysis
//     "frequency" for AC analysis
//     "sweep" or "v-sweep" for DC analysis
// The table header line is followed by another line of dashes.
// Then the data lines begin, starting with index value 0.
//
// Not all of the following lines are guaranteed to be data lines.
// Unless the ".OPTIONS nopage" command was issued, ngspice inserts an empty line
// at about every 50th data line, then repeats the table header and a line of dashes,
// then continues with the data lines.
//
// Sample NGSPICE output is available in the unit test "test_spice_output_parser.mm".
VoltaPTSimulationDataPtr FXSpiceOutputParser::parse(FXString input)
{
  FXStringVector lines = input.getLines(false);
  VoltaPTSimulationDataPtr simulationData(new VoltaPTSimulationData);

  size_t currentLineIndex = 0; // index of current processed line
  
  FXSpiceOutputParsingMode mode = FXSpiceOutputParsingMode::LookingForCircuit;

  while ( currentLineIndex < lines.size() )
  {
    if (mode == FXSpiceOutputParsingMode::LookingForCircuit)
    {
      mode = processLine_LookingForCircuit(lines, currentLineIndex, simulationData);
    }
    else if (mode == FXSpiceOutputParsingMode::LookingForAnalysis)
    {
      mode = processLine_LookingForAnalysis(lines, currentLineIndex, simulationData);
    }
    else if (mode == FXSpiceOutputParsingMode::LookingForTableData)
    {
      mode = processLine_LookingForTableData(lines, currentLineIndex, simulationData);
    }
  }

  return simulationData;
}
