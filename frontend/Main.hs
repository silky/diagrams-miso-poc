{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- I needed this:
--
--  LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libgtk3-nocsd.so.0
--
-- and
--
--  export PATH=/home/noon/.stack/programs/x86_64-linux/ghc-7.10.2/bin/:$PATH
--
-- and maybe I also needed 'alex' installed globally.


module Main where

import Control.Monad.IO.Class
import Miso
import Miso.String hiding (map, count)
import Diagrams.Prelude hiding (text, start, Attribute, (<>))
import Diagrams.Backend.Miso
import Data.Colour.SRGB
import Control.Exception (try, catch, SomeException, evaluate)

data Model = Model
       { background :: !(Colour Double)
       , count      :: !Double
       , factor     :: !Double
       } deriving (Eq)


initModel = Model { background = sRGB24read "#ff0099"
                  , count      = 5
                  , factor     = 1/2
                  }


data Action
  = TryChangeBackgroundColour !MisoString
  | DefinitelyChangeBackgroundColour !(Colour Double)
  | ChangeCount !MisoString
  | ChangeFactor !MisoString
  | NoOp
  deriving (Show, Eq)


d :: Model -> Diagram B
d model = 
  hcat circles
    # frame 0.5
    # bg ( background model )
  where
    f       = factor model
    circles = map circle [f ** k | k <- [1..count model]]


main :: IO ()
main = startApp App {..}
  where
    initialAction = NoOp     -- initial action to be executed on application load
    model  = initModel       -- initial model
    update = updateModel     -- update function
    view   = viewModel       -- view function
    events = defaultEvents   -- default delegated events
    subs   = []              -- empty subscription list
    mountPoint = Nothing     -- mount point for application (Nothing defaults to 'body')



-- | Updates model, optionally introduces side effects
updateModel :: Action -> Model -> Effect Action Model
updateModel NoOp m = noEff m
updateModel (ChangeCount s) m =
  noEff $ m { count = read (fromMisoString s) }
updateModel (ChangeFactor s) m =
  noEff $ m { factor = read (fromMisoString s) }
updateModel (DefinitelyChangeBackgroundColour c) m = 
  noEff $ m { background = c }
updateModel (TryChangeBackgroundColour s) m = 
  m <# do
    -- HACK: We need the evaluate here because we want the error
    -- right now; instead of when the "DefinitelyChanged" thing 
    -- is evaluated, because, for reasons, an error at that point
    -- causes the entire JS app to end.
    --
    -- See: https://github.com/dmjio/miso/issues/468
    --
    newColour <- evaluate $ sRGB24read (fromMisoString s)
    pure $ DefinitelyChangeBackgroundColour newColour


diagram :: Model -> View Action
diagram model =
  div_ [] [ div_ [ class_ "inputs" ]
                 [ label_ [ for_ "BackgroundColour" ] [text "Background Colour"]
                 , input_ 
                     [ type_ "text"
                     , name_ "BackgroundColour"
                     , onInput TryChangeBackgroundColour
                     , value_ (ms (sRGB24show (background model)))
                     ]
                 , label_ [ for_ "Count" ] [text $ "Count: " <> ms (count model)]
                 , input_ 
                     [ type_ "range"
                     , name_ "Count"
                     , onInput ChangeCount
                     , value_ (ms (count model))
                     , min_ "1"
                     , max_ "20"
                     , step_ "1"
                     ]
                 --
                 , label_ [ for_ "Factor" ] [text $ "Factor: " <> ms (factor model)]
                 , input_ 
                     [ type_ "range"
                     , name_ $ "Factor"
                     , onInput ChangeFactor
                     , value_ (ms (factor model))
                     , min_ "0.1"
                     , max_ "2"
                     , step_ "0.1"
                     ]
                 ]
          , div_  [ class_ "diagram" ] 
                  [ misoDia (def & sizeSpec .~ mkWidth 400) (d model) [] ]
          ]


viewModel :: Model -> View Action
viewModel x = div_ [] 
  [ link_ [ rel_ "stylesheet" , href_ "style.css" ]
  , h1_ [] [ text "Miso Diagrams POC" ]
  , diagram x
  , a_ [href_ "https://github.com/silky/diagrams-miso-poc"] [ text "View Source on GitHub" ]
  ]
