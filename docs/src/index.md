# JAXTAM.jl Documentation

```@contents
```

## IO

### User Configuration

```@docs
JAXTAM.config
JAXTAM.config_rm
```

### Master Table Management

```@docs
JAXTAM.master
JAXTAM.master_query
```

## API

These are low(er)-level functions which typically shouldn't be called by users.

```@docs
JAXTAM._config_gen
JAXTAM._config_load
JAXTAM._config_edit
JAXTAM._config_rm
JAXTAM._config_key_value
```

```@docs
JAXTAM._master_read_tdat
JAXTAM._master_save
```