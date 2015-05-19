module Data.Argonaut.Decode
  ( DecodeJson
  , decodeJson
  , decodeMaybe
  -- Lenses
  , decodeL
  , arrayIndexL
  , objectFieldL
  ) where

  import Optic.Core (PrismP())
  import Optic.Extended (TraversalP())
  import Optic.Index (ix)
  import Optic.Prism (prism')

  import Data.Argonaut.Core
    ( Json()
    , JNumber()
    , JString()
    , arrayL
    , foldJsonNull
    , foldJsonBoolean
    , foldJsonNumber
    , foldJsonString
    , foldJsonArray
    , foldJsonObject
    , objectL
    , toArray
    , toNumber
    , toObject
    , toString
    )
  import Data.Argonaut.Encode (encodeJson, EncodeJson)
  import Data.Either (either, Either(..))
  import Data.Int (Int(), fromNumber)
  import Data.Maybe (maybe, Maybe(..))
  import Data.Foldable (Foldable, foldl, foldMap, foldr)
  import Data.Traversable (Traversable, traverse)
  import Data.Tuple (Tuple(..), uncurry)
  import Data.String
  import Data.Char(Char())
  import Control.Alt
  import Data.Traversable (traverse)

  import qualified Data.StrMap as M
  import qualified Data.Map as Map

  class DecodeJson a where
    decodeJson :: Json -> Either String a

  instance decodeJsonMaybe :: (DecodeJson a) => DecodeJson (Maybe a) where
    decodeJson j = (Just <$> decodeJson j) <|> pure Nothing

  instance decodeJsonTuple :: (DecodeJson a, DecodeJson b) => DecodeJson (Tuple a b) where
    decodeJson j = decodeJson j >>= f where
      f (a : (b : [])) = Tuple <$> decodeJson a <*> decodeJson b

  instance decodeJsonEither :: (DecodeJson a, DecodeJson b) => DecodeJson (Either a b) where
    decodeJson j = (Left <$> decodeJson j) <|> (Right <$> decodeJson j)

  instance decodeJsonNull :: DecodeJson Unit where
    decodeJson = foldJsonNull (Left "Not null.") (const $ Right unit)

  instance decodeJsonBoolean :: DecodeJson Boolean where
    decodeJson = foldJsonBoolean (Left "Not a Boolean.") Right

  instance decodeJsonNumber :: DecodeJson Number where
    decodeJson = foldJsonNumber (Left "Not a Number.") Right

  instance decodeJsonInt :: DecodeJson Int where
    decodeJson = foldJsonNumber (Left "Not a Number.") (Right <<< fromNumber)

  instance decodeJsonString :: DecodeJson String where
    decodeJson = foldJsonString (Left "Not a String.") Right

  instance decodeJsonJson :: DecodeJson Json where
    decodeJson = Right

  instance decodeJsonChar :: DecodeJson Char where
    decodeJson j = (charAt 0 <$> decodeJson j) >>= go where
      go Nothing  = Left $ "Expected character but found: " ++ show j
      go (Just c) = Right c

  instance decodeStrMap :: (DecodeJson a) => DecodeJson (M.StrMap a) where
    decodeJson json = maybe (Left "Couldn't decode.") Right $ do
      obj <- toObject json
      traverse decodeMaybe obj

  instance decodeArray :: (DecodeJson a) => DecodeJson [a] where
    decodeJson json = maybe (Left "Couldn't decode.") Right $ do
      obj <- toArray json
      traverse decodeMaybe obj

  instance decodeMap :: (Ord a, DecodeJson a, DecodeJson b) => DecodeJson (Map.Map a b) where
    decodeJson j = Map.fromList <$> decodeJson j

  decodeMaybe :: forall a. (DecodeJson a) => Json -> Maybe a
  decodeMaybe json = decodeJson json # either ((const Nothing) :: forall a. String -> Maybe a) Just

  decodeL :: forall a. (DecodeJson a, EncodeJson a) => PrismP Json a
  decodeL = prism' encodeJson decodeMaybe

  arrayIndexL :: forall a. (DecodeJson a, EncodeJson a) => JNumber -> TraversalP Json a
  arrayIndexL i = decodeL >>> ix i >>> arrayL

  objectFieldL :: forall a. (DecodeJson a, EncodeJson a) => JString -> TraversalP Json a
  objectFieldL key = decodeL >>> ix key >>> objectL

  -- objectMembersL :: forall a. (DecodeJson a, EncodeJson a) => IndexedTraversalP JString Json a
  -- objectMembersL = decodeL >>> itraversed >>> objectL

  -- arrayMembersL :: forall a. (DecodeJson a, EncodeJson a) => IndexedTraversalP JNumber Json a
  -- arrayMembersL = decodeL >>> traversed >>> arrayL
