struct JAXTAMError <: Exception
    msg   :: String
    step  :: Symbol
    super :: Union{Nothing, Exception} 

    JAXTAMError(msg::String, step::Symbol) = new(msg, step, nothing)

    JAXTAMError(msg::String, step::Symbol, super::Exception) = new(msg, step, super)
end