module Ttt.Domain where

import Prelude

import Effect (Effect)
import Data.Functor.Contravariant (cmap)
import Data.Lens (Lens', lens, lens', (^.), (.~), (%~))
import Data.Maybe (Maybe (..), isNothing)
import Data.Foldable (class Foldable, fold, foldl, foldMap, findMap, foldrDefault, foldlDefault)
import Data.Monoid (guard)
import Data.Tuple (Tuple)
import Data.Tuple.Nested ((/\))
import Data.Set as Set
import Data.Generic.Rep (class Generic)
import Data.Show.Generic (genericShow)
import Data.Eq.Generic (genericEq)

import Mation as M
import Mation.Core.Refs as Refs
import Mation.Elems as E
import Mation.Props as P
import Mation.Styles as S
import Mation.Lenses (field)


type Endo a = a -> a


-- Game board, parameterized by cell type
type Board a = Triple (Triple a)

-- Index type for a Board: (x, y)
type BoardIx = Tuple TripleIx TripleIx

-- X or O
data XO = X | O

derive instance Generic XO _
derive instance Eq XO
instance Show XO where show = genericShow


-- Size-three list
data Triple a = Triple a a a

derive instance Generic (Triple a) _
derive instance Functor Triple
instance Eq a => Eq (Triple a) where eq = genericEq

instance Foldable Triple where
  foldMap f (Triple a b c) = f a <> f b <> f c
  foldr x = foldrDefault x
  foldl x = foldlDefault x


-- Index type for Triple
data TripleIx = Fst | Snd | Thd

derive instance Generic TripleIx _
derive instance Eq TripleIx

-- Index into a Triple
ix :: forall a. TripleIx -> Lens' (Triple a) a
ix = case _ of
  Fst -> lens (\(Triple a _ _) -> a) (\(Triple _ b c) a -> Triple a b c)
  Snd -> lens (\(Triple _ b _) -> b) (\(Triple a _ c) b -> Triple a b c)
  Thd -> lens (\(Triple _ _ c) -> c) (\(Triple a b _) c -> Triple a b c)


type Model =
  { board :: TttBoard
  , nextPlayer :: XO
  }

-- Concrete game board type for tic-tac-toe
type TttBoard = Board (Maybe XO)

-- Make a play on a board
playAt :: forall r. BoardIx -> Endo { board :: TttBoard, nextPlayer :: XO }
playAt (x /\ y) model =
  model
  # ((field @"board" <<< ix y <<< ix x) .~ Just model.nextPlayer)
  # (field @"nextPlayer" %~ case _ of X -> O
                                      O -> X)


-- If there is a winner, produces the winner along with
-- the winning cells.
getCurrentWin :: TttBoard -> Maybe { winner :: XO, winningCells :: Triple BoardIx }
getCurrentWin board =

  winningRuns # findMap \candidateRun ->
    let runCells = candidateRun <#> \(cellX /\ cellY) -> board ^. (ix cellY <<< ix cellX)
    in case runCells of
      Triple (Just X) (Just X) (Just X) -> Just { winner: X, winningCells: candidateRun }
      Triple (Just O) (Just O) (Just O) -> Just { winner: O, winningCells: candidateRun }
      _ -> Nothing

  where

  -- All possible ways to win
  winningRuns =
    [ Triple (Fst /\ Fst) (Snd /\ Fst) (Thd /\ Fst)  -- Top row
    , Triple (Fst /\ Snd) (Snd /\ Snd) (Thd /\ Snd)  -- Middle row
    , Triple (Fst /\ Thd) (Snd /\ Thd) (Thd /\ Thd)  -- Bottom row
    , Triple (Fst /\ Fst) (Fst /\ Snd) (Fst /\ Thd)  -- Left column
    , Triple (Snd /\ Fst) (Snd /\ Snd) (Snd /\ Thd)  -- Middle column
    , Triple (Thd /\ Fst) (Thd /\ Snd) (Thd /\ Thd)  -- Right column
    , Triple (Fst /\ Fst) (Snd /\ Snd) (Thd /\ Thd)  -- Top-left-to-bottom-right diagonal
    , Triple (Fst /\ Thd) (Snd /\ Snd) (Thd /\ Fst)  -- Bottom-left-to-top-right diagonal
    ]

