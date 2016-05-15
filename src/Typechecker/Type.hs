{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE TemplateHaskell #-}


module Typechecker.Type where

import Data.Map                 (Map, lookup, insert, empty)
import Control.Monad.Except     (throwError)
import Control.Lens
import Control.Monad.State      (put, get)

import Types (F(..), L(..), B(..), P(..), S(..), TType(..), T(..), E(..))
import AST (Expr(..), Stm(..), Block(..), LHVal(..), ExprList(..), AOp(..), Appl(..), BOp(..), UnOp(..))
import Typechecker.Subtype ((<?))
import Typechecker.Utils
import Data.List (transpose)


    

tBlock :: Block -> TypeState ()
tBlock (Block bs) = mapM_ tStmt bs

tStmt :: Stm -> TypeState ()
tStmt Skip = tSkip Skip
tStmt t@(StmTypedVarDecl _ _ _) = tLocal1 t
--tStmt a@(StmAssign _ _) = tAssignment a


-- T-LOCAL1
tLocal1 :: Stm -> TypeState ()
tLocal1 (StmTypedVarDecl fvars exps (Block blck)) = do
    e <- tExpList exps
    expListS <- e2s e
    let tvars = fmap snd fvars
        fvarsS = SP $ P tvars (Just FValue)
    case expListS <? fvarsS of
        False -> throwError $ "tLocal1 error" 
        True  -> do
            env <- get
            let gammaMap = env ^. gamma
                newMap = foldl insertFun gammaMap fvars
            put $ env & gamma .~ newMap
            mapM_ tStmt blck 
    where insertFun gmap (k,v) = insert k (TF v) gmap        

---- T-LOCAL2
----tLocal2 :: Stat -> TypeState ()
----tLocal2 (LocalAssign vars exps (Block blck)) = do
----    let P texps (Just e) = tExpList exps

getAppType :: Appl -> TypeState S
getAppType = error "getAppType"
getTypeId :: LHVal -> TypeState F
getTypeId = error "getTypeId"

---- T-LHSLIST
--tLHSList :: [LHVal] -> TypeState S
--tLHSList vars = do
--    fs <- mapM getTypeId vars
--    return . SP $ P fs (Just FValue)

 --T-EXPLIST 1, 1, 1
tExpList :: ExprList -> TypeState E
tExpList (ExprList exps Nothing) = E <$> (mapM getTypeExp exps) <*> (pure . Just . TF $ FNil)
tExpList (ExprList exps (Just me)) = do
    appType <- getAppType me
    tExps <- mapM getTypeExp exps
    case appType of
        SP (P fs mf) -> E <$> merge tExps fs <*> mF2mT mf
        SUnion ps -> ps2Projections tExps ps

    where merge tExps fs = do
            return $ tExps ++ (fmap TF fs)
          mF2mT maybeF = return $ fmap TF maybeF

ps2Projections :: [T] -> [P] -> TypeState E
ps2Projections tExps ps = do
    x <- tic
    insertSToPi x (SUnion ps)
    let unwrapped = fmap unwrap ps
        maxLen = maximum $ fmap length unwrapped
        projections = fmap (TProj x) [1..maxLen]
    E <$> return (tExps ++ projections) <*> (pure . Just . TF $ FNil)

  where unwrap (P fs _) = fs




-- T-SKIP
tSkip :: Stm -> TypeState ()
tSkip _ = return ()


--tExpList23 :: ExprList -> TypeState T
--tExpList23 (ExprList exps (Just app)) = 


-- T-APPLY
--tApply :: FunAppl -> TypeState S
--tApply (FunAppl exp expList) = do
--    TF funType <- lookupGamma exp




-- T-ASSIGNMENT1
--tAssignment :: Stm -> TypeState ()
--tAssignment (StmAssign vars exps) = do
--    P texps (Just e) <- tExpList1 exps
--    P tvars (Just v) <- tLHSList vars
--    let varTypeTuple = tupleZip texps e tvars v
--    let typingResult = fmap (\(x,y) -> x <? y) varTypeTuple 
--    tlog $ "Assignment: " ++ (show typingResult)
--    case all id typingResult of
--        True -> return ()
--        False -> throwError "False in tAssignment"


getTypeExp :: Expr -> TypeState T
getTypeExp = \case
    ExpNil                     -> return . TF $ FNil
    ExpTrue                    -> return . TF $ FL LTrue
    ExpFalse                   -> return . TF $ FL LFalse
    ExpInt s                   -> return . TF . FL $ LInt s
    ExpFloat s                 -> return . TF . FL $ LFloat s
    ExpString s                -> return . TF . FL $ LString s
    ExpTypeCoercion f _        -> return . TF $ f
    ExpVar var                 -> lookupGamma var 
    --e@(ExpABinOp Add _ _)      -> TF <$> tArith e
    --e@(ExpABinOp Concat _ _)   -> TF <$> tConcat e
    --e@(ExpABinOp Equals _ _)   -> TF <$> tEqual e
    --e@(ExpABinOp LessThan _ _) -> TF <$> tOrder e
    --e@(ExpBBinOp Amp _ _)      -> TF <$> tBitWise e
    --e@(ExpBBinOp And _ _)      -> TF <$> tAnd e
    --e@(ExpBBinOp Or _ _)       -> TF <$> tOr e
    --e@(ExpUnaryOp Not _)       -> TF <$> tNot e
    --e@(ExpUnaryOp Hash _)      -> TF <$> tLen e    



--getTypeId :: LHVal -> TypeState F
--getTypeId (IdVal id) = do
--    env <- get
--    case env ^. gamma ^.at id of
--        Just (TF f) -> return f
--        Nothing -> throwError $ "Cannot find variable" ++ id

--tupleZip ls l rs r | length ls == length rs = zip ls rs
--                   | length ls < length rs = zip (ls ++ repeat l) rs
--                   | otherwise = zip ls (rs ++ repeat r)


---- TODO: components should have type F
--tArith :: Expr -> TypeState F
--tArith (ExpABinOp Add e1 e2) = do
--    f1 <- getTypeExp e1
--    f2 <- getTypeExp e2
--    if f1 <? (FB BInt) && f2 <? (FB BInt)
--    then return (FB BInt)
--    else if (f1 <? (FB BInt) && f2 <? (FB BNumber)) || (f2 <? (FB BInt) && f1 <? (FB BNumber))
--         then return (FB BNumber)
--         else if f1 <? (FB BNumber) && f2 <? (FB BNumber)
--              then return (FB BNumber)
--              else if f1 == FAny || f2 == FAny 
--              then return FAny
--              else throwError "tArith cannot typecheck"



--tConcat :: Expr -> TypeState F
--tConcat (ExpABinOp Concat e1 e2) = do
--    f1 <- getTypeExp e1
--    f2 <- getTypeExp e2
--    if f1 <? (FB BString) && f2 <? (FB BString)
--    then return (FB BString)
--    else if f1 == FAny && f2 == FAny
--         then return FAny
--         else throwError "tConcat cannot typecheck"

--tEqual :: Expr -> TypeState F
--tEqual (ExpABinOp Equals e1 e2) = return (FB BBoolean)

--tOrder :: Expr -> TypeState F
--tOrder (ExpABinOp LessThan e1 e2) = do
--    f1 <- getTypeExp e1
--    f2 <- getTypeExp e2
--    if f1 <? (FB BNumber) && f2 <? (FB BNumber) 
--    then return (FB BBoolean)
--    else if f1 <? (FB BString) && f2 <? (FB BString)
--         then return (FB BString)
--         else if f1 == FAny || f2 == FAny
--              then return FAny
--              else throwError "tOrder cannot typecheck"


--tBitWise :: Expr -> TypeState F
--tBitWise (ExpBBinOp Amp e1 e2) = do
--    f1 <- getTypeExp e1
--    f2 <- getTypeExp e2
--    if f1 <? (FB BInt) && f2 <? (FB BInt)
--    then return (FB BInt)
--    else if f1 == FAny || f2 == FAny
--         then return FAny
--         else throwError "tBitWise cannot typecheck"


--tAnd :: Expr -> TypeState F
--tAnd (ExpBBinOp And e1 e2) = do
--    f1 <- getTypeExp e1
--    f2 <- getTypeExp e2
--    if f1 == FNil || f1 == (FL LFalse) || f1 == FUnion [FNil, FL LFalse]
--    then return f1
--    else if not (FNil <? f1) && not ((FL LFalse) <? f1)
--         then return f2
--         else return $ FUnion [f1, f2]

--tOr :: Expr -> TypeState F
--tOr (ExpBBinOp Or e1 e2) = do
--    f1 <- getTypeExp e1
--    f2 <- getTypeExp e2  
--    if not (FNil <? f1) && not ((FL LFalse)  <? f2)
--    then return f1
--    else if f1 == FNil || f1 == (FL LFalse) || f1 == FUnion [FNil, FL LFalse]
--         then return f2
--         else throwError "tOr unimplemented tOr5"

--tNot :: Expr -> TypeState F
--tNot (ExpUnaryOp Not e1) = do
--    f <- getTypeExp e1
--    if f == FNil || f == (FL LFalse) || f == FUnion [FNil, FL LFalse]
--    then return $ FL LTrue
--    else if not (FNil <? f) && not ((FL LFalse) <? f)
--         then return $ FL LFalse
--         else return $ FB BBoolean

--tLen :: Expr -> TypeState F
--tLen (ExpUnaryOp Hash e1) = do
--    f <- getTypeExp e1
--    if f <? (FB BString) || f <? (FTable [] Closed)
--    then return $ FB BInt
--    else if f == FAny
--         then return FAny 
--         else throwError "tLen cannot typecheck"