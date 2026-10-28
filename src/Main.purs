module Main where

import Prelude

import Effect (Effect)
import Data.Functor.Contravariant (cmap)
import Data.Lens (Lens', lens, lens', (^.), (.~), (%~))
import Data.Maybe (Maybe (..), isNothing, fromMaybe)
import Data.Foldable (fold, foldMap, elem)
import Data.Monoid (guard)
import Data.Tuple.Nested ((/\))

import Mation as M
import Mation.Core.Refs as Refs
import Mation.Elems as E
import Mation.Props as P
import Mation.Styles as S
import Mation.Lenses (field)

import Ttt.Domain


initial :: Model
initial =
  { board: Triple
      (Triple Nothing Nothing Nothing)
      (Triple Nothing Nothing Nothing)
      (Triple Nothing Nothing Nothing)
  , nextPlayer: X
  }

render :: Model -> E.Html' { model :: M.Modify Model }
render model =
  let mCurrentWin = getCurrentWin model.board
  in
  E.div
  [ P.addStyles
    [ S.display "flex"
    , S.flexDirection "column"
    , S.minHeight "60vh"
    , S.alignItems "center"
    , S.justifyContent "center"
    , S.fontFamily "sans-serif"
    ]
  ]
  [ E.table
    [ P.remark "game board"
    , P.addStyles
      [ S.textAlign "center"
      , S.fontSize "30px"
      ]
    ]
    [ [Fst, Snd, Thd] # foldMap \y ->
      E.tr
      [ P.remark "game board row"
      ]
      [ [Fst, Snd, Thd] # foldMap \x ->
        let cell = model.board ^. (ix y <<< ix x)
        in
        E.td
        [ P.remark "game board cell"
        , P.addStyles
          [ (S.width <> S.height) "2em"
          , S.border "1px solid grey"
          ]
        , let isInWinRun = fromMaybe false do
                currentWin <- mCurrentWin
                pure $ (x /\ y) `elem` currentWin.winningCells
          in guard isInWinRun $
            P.addStyles
            [ S.background "rgba(0, 200, 0, 0.25)"
            ]
        , case cell of
          Just _ -> fold
            [ P.addStyles
              [ S.pointerEvents "none"
              ]
            ]
          Nothing ->
            fold
            [ P.onClick \e k -> k.model # Refs.modify (playAt (x /\ y))
            , P.addStyles
              [ S.cursor "pointer"
              ]
            ]
            # guard (isNothing mCurrentWin)  -- Disable interactivity on complete game
        ]
        [ case cell of
            Just X -> E.text "X"
            Just O -> E.text "O"
            Nothing -> mempty
        ]
      ]
    ]
  , E.p
    []
    [ E.text $ case mCurrentWin of
        Just { winner } -> "Winner! " <> show winner
        Nothing -> "Next: " <> show model.nextPlayer
    ]
  ]

main :: Effect Unit
main =
  M.runApp
    { initial
    , render: render >>> cmap (\ref -> { model: Refs.downcast ref })
    , root: M.underBody
    , daemon: mempty
    }
