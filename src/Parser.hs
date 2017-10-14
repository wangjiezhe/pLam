module Parser where

import Control.Monad.State
import Text.Parsec hiding (State)
import Debug.Trace
import Data.Char

import qualified Text.Parsec.Token as Token
import Text.Parsec.Language

import Syntax

-------------------------------------------------------------------------------------
languageDef =
    emptyDef { Token.commentLine     = "--"
             , Token.identStart      = letter
             , Token.identLetter     = alphaNum
             , Token.reservedNames   = [ "execute"
                                       , "import"
                                       , "review"
                                       , "run"
                                       ]
             , Token.reservedOpNames = [ "="
                                       , "." 
                                       , "\\"
                                       ]
             }

lexer = Token.makeTokenParser languageDef

identifier = Token.identifier lexer
reserved   = Token.reserved   lexer 
reservedOp = Token.reservedOp lexer 
parens     = Token.parens     lexer
-------------------------------------------------------------------------------------

type Parser = Parsec String ()

-------------------------------------------------------------------------------------
symbol :: Parser Char
symbol = oneOf ".`#~@$%^&*_+|;:',/?[]<> "

comment :: Parser String
comment = many $ letter <|> symbol <|> digit

filename :: Parser String
filename = many1 $ letter <|> symbol <|> digit

fromNumber :: Int -> Expression -> Expression
fromNumber 0 exp = Abstraction (LambdaVar 'f' 0) (Abstraction (LambdaVar 'x' 0) exp)
fromNumber n exp = fromNumber (n-1) (Application (Variable (LambdaVar 'f' 0)) exp)
-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------
parseChurch :: Parser Expression
parseChurch = do
    strNum <- many1 digit
    let intNum = read strNum :: Int
    return (fromNumber intNum (Variable (LambdaVar 'x' 0)))

parseVariable :: Parser Expression
parseVariable = do
    x <- identifier
    spaces
    case (length x) of
        1 -> return (Variable (LambdaVar (head x) 0))
        otherwise -> return (EnvironmentVar x) 

parseAbstraction :: Parser Expression
parseAbstraction = do
  reservedOp "\\"
  xs <- letter `endBy1` spaces
  reservedOp "."
  spaces
  body <- parseApplication
  return $ curry xs body where
        curry (x:xs) body = Abstraction (LambdaVar x 0) $ curry xs body
        curry [] body     = body

parseApplication :: Parser Expression
parseApplication = do
  es <- parseExpression `sepBy1` spaces
  return $ foldl1 Application es

parseExpression :: Parser Expression
parseExpression =  parens parseApplication
               <|> parseChurch
               <|> parseVariable
               <|> parseAbstraction
-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------
parseDefine :: Parser Command
parseDefine = do
    var <- identifier
    spaces
    reservedOp "="
    spaces
    y <- parseExpression
    return $ Define var y

parseExecute :: Parser Command
parseExecute = do
    reserved "execute"
    spaces
    ex <- parseExpression
    return $ Execute ex

parseImport :: Parser Command
parseImport = do
    reserved "import"
    spaces
    f <- filename
    return $ Import f

parseReview :: Parser Command
parseReview = do
    reserved "review"
    spaces
    f <- identifier
    return $ Review f

parseComment :: Parser Command
parseComment = do
    comm <- string "--"
    c <- comment
    return $ Comment c

parseRun :: Parser Command
parseRun = do
    reserved "run"
    spaces
    f <- filename
    return $ Run f
    
parseLine :: Parser Command
parseLine = parseDefine
         <|> parseExecute
         <|> parseImport
         <|> parseReview
         <|> parseRun
         <|> parseComment
-------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------
readLine :: String -> Failable Command
readLine input = case parse parseLine "parser" input of
    Left err -> Left $ SyntaxError err
    Right l -> Right l 

