//------------------------------------------------------------------------------
// Dijkstra on PyCoRAM (Software)
// Copyright (C) 2013, Shinya Takamaeda-Yamazaki
// License: Apache 2.0
//------------------------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>

typedef unsigned int Uint;

//#define __STATIC__

//#define MAX_NODES (128 * 1024 * 1024)
#define MAX_NODES (32 * 1024 * 1024)
#define MAX_PAGES (32 * 1024 * 1024)
#define PAGE_SIZE (16)

//#define HASHTABLE_SIZE (MAX_NODES)
//#define HASH(__id__) (__id__ % HASHTABLE_SIZE)

#define MAX_INT (2147483647)

//------------------------------------------------------------------------------
typedef struct node Node;
typedef struct page Page;
typedef struct edge Edge;

struct node
{
  Uint id;
  Node* parent_node;
  Uint current_cost;
  //Uint predicted_cost; // = current_cost + heuristic
  Uint visited;
  Page* next_node_page_chain; // chain of neighbor node tables
  //Node* hash_chain; // oldest first order
  Node* frontier_chain;
};

struct edge
{
  Node* next_node;
  Uint cost;
};

struct page
{
  Uint num_entries;
  Page* next_page;
  Edge edges [PAGE_SIZE];
};

//------------------------------------------------------------------------------
Uint number_of_nodes;
Uint number_of_edges;

#ifdef __STATIC__
Node node_array [MAX_NODES];
Page page_array [MAX_PAGES];
//Node* hashtable [HASHTABLE_SIZE]; // to search a node
#else
Node* node_array;
Page* page_array;
//Node** hashtable; // to search a node
#endif

Node* frontiers_tail;

Uint node_index; // for node count
Uint page_index; // for edge count

//------------------------------------------------------------------------------
Node* add_node(Uint id)
{
  Node* p;
  p = &node_array[id];
  p->id = id;
  p->parent_node = NULL;
  p->current_cost = 0;
  p->visited = 0;
  //p->next_node_page_chain = NULL;
  p->frontier_chain = NULL;
  return p;

  /*
  p = hashtable[HASH(id)];

  if(p == NULL){ // new entry for hashtable
    hashtable[HASH(id)] = &node_array[node_index];
    node_index++;
    hashtable[HASH(id)]->id = id;
    hashtable[HASH(id)]->parent_node = NULL;
    hashtable[HASH(id)]->current_cost = 0;
    hashtable[HASH(id)]->visited = 0;
    hashtable[HASH(id)]->next_node_page_chain = NULL;
    hashtable[HASH(id)]->hash_chain = NULL;
    hashtable[HASH(id)]->frontier_chain = NULL;
    return hashtable[HASH(id)];
  }

  while(1){ // concat with existing entries
    if(p->id == id){
      return p; // already exists
    }
    if(p->hash_chain == NULL){ // tail
      p->hash_chain = &node_array[node_index];
      node_index++;
      p->hash_chain->id = id;
      p->hash_chain->parent_node = NULL;
      p->hash_chain->current_cost = 0;
      p->hash_chain->visited = 0;
      p->hash_chain->next_node_page_chain = NULL;
      p->hash_chain->hash_chain = NULL;
      p->hash_chain->frontier_chain = NULL;
      return p->hash_chain;
    }
    p = p->hash_chain;
  }

  return NULL;
  */
}

//------------------------------------------------------------------------------
void add_edge(Uint from, Uint to, Uint cost)
{
  Node* f = add_node(from);
  Node* t = add_node(to);

  if(f->next_node_page_chain == NULL){
    // New page
    f->next_node_page_chain = &page_array[page_index];
    page_index++;

    f->next_node_page_chain->next_page = NULL;
    f->next_node_page_chain->num_entries = 0;
  }

  Page* p = f->next_node_page_chain;
  while(p->next_page != NULL){
    p = p->next_page;
  }
  
  if(p->num_entries < PAGE_SIZE){
    p->edges[p->num_entries].next_node = t;
    p->edges[p->num_entries].cost = cost;
    p->num_entries++;
  }else{
    // New page
    p->next_page = &page_array[page_index];
    page_index++;

    p->next_page->next_page = NULL;
    p->next_page->num_entries = 0;

    p = p->next_page;
    p->edges[p->num_entries].next_node = t;
    p->edges[p->num_entries].cost = cost;
    p->num_entries++;
  }
}

//------------------------------------------------------------------------------
Node* get_node(Uint id)
{
  Node* p;
  p = &node_array[id];
  return p;
  /*
  p = hashtable[HASH(id)];
  while(p != NULL){
    if(p->id == id) return p;
    p = p->hash_chain;
  }
  return NULL; // not found
  */
}

//------------------------------------------------------------------------------
void add_frontier(Node* n)
{
  if(frontiers_tail == NULL){
    frontiers_tail = n;
    n->frontier_chain = n;
  }
  else{
    n->frontier_chain = frontiers_tail;
    frontiers_tail = n;
  }
}

//------------------------------------------------------------------------------
void update_frontiers(Node* current_node)
{
  Uint current_cost = current_node->current_cost;
  Page* page = current_node->next_node_page_chain;

  while(page != NULL){
    Uint num_next = page->num_entries;
    Uint i;

    for(i=0; i<num_next; i++){
      Uint cost = page->edges[i].cost;
      Node* next_node = page->edges[i].next_node;
      
      if(next_node->frontier_chain){ // already in frontier_list
        if(next_node->current_cost > current_cost + cost){
          next_node->current_cost = current_cost + cost;
          //Uint heuristic = 0;
          //next_node->predicted_cost = current_cost + cost + heuristic;
          next_node->parent_node = current_node;
        }
      }
      else if( !(next_node->visited) ){
        add_frontier(next_node);
        next_node->current_cost = current_cost + cost;
        //Uint heuristic = 0;
        //next_node->predicted_cost = current_cost + cost + heuristic;
        next_node->parent_node = current_node;
      }
      else{
        //// for A* algorithm
        //if(next_node->current_cost > current_cost + cost){
        //  add_frontier(next_node);
        //  next_node->current_cost = current_cost + cost;
        //  Uint heuristic = 0;
        //  next_node->predicted_cost = current_cost + cost + heuristic;
        //  next_node->parent_node = current_node;
        //}
      }
    }
    
    page = page->next_page;
  }
}

//------------------------------------------------------------------------------
Node* select_frontier()
{
  Node* p = frontiers_tail;
  Node* prev = frontiers_tail;
  Node* prev_candidate_node = frontiers_tail;
  Node* candidate_node = frontiers_tail;
  Uint min_cost = MAX_INT;

  while(p != NULL){
    //if(p->predicted_cost < min_cost){ // A* algorithm
    if(p->current_cost < min_cost){
      candidate_node = p;
      prev_candidate_node = prev; 
      min_cost = p->current_cost;
    }
    // frontier_chain of the last node is a pointer to itself
    if(p == p->frontier_chain){
      break;
    }
    prev = p;
    p = p->frontier_chain;
  }

  if(p == NULL){
    printf("Could not find a path\n");
    exit(-1);
  }

  if(candidate_node->frontier_chain == candidate_node){
    if(prev_candidate_node != candidate_node){
      prev_candidate_node->frontier_chain = prev_candidate_node;
    }
    else{
      prev_candidate_node->frontier_chain = NULL;
      frontiers_tail = NULL;
    }
  }
  else{
    if(prev_candidate_node != candidate_node){
      prev_candidate_node->frontier_chain = candidate_node->frontier_chain;
    }
    else{
      frontiers_tail = candidate_node->frontier_chain;
    }
  }

  candidate_node->frontier_chain = NULL;
  candidate_node->visited = 1;

  return candidate_node;
}

//------------------------------------------------------------------------------
Uint find_shortest_path(Uint start, Uint goal)
{
  Node* current_node = get_node(start);
  add_frontier(current_node);

  while(current_node->id != goal){
    current_node = select_frontier();
    update_frontiers(current_node);
  }

  return current_node->current_cost;
}

//------------------------------------------------------------------------------
Uint compute(Uint start, Uint goal)
{
  return find_shortest_path(start, goal);
}

//------------------------------------------------------------------------------
void walk_result(Uint sum_of_cost, Uint start, Uint goal)
{
  Node* c = get_node(goal);
  printf("route: ");

  while(c != NULL){
    //printf("%d, ", c->id);
    printf("%d\n", c->id);
    if(c->id == start) break;
    c = c->parent_node;
  }
  
  printf("\r\n");
  printf("cost: %d", sum_of_cost);
  printf("\r\n");
}

//------------------------------------------------------------------------------
int main(int argc, char** argv)
{

  FILE* fp = fopen(argv[3], "r");
  if(fp == NULL){
    printf("no such file\n");
    return -1;
  }

  Uint start = atoi(argv[1]);
  Uint goal = atoi(argv[2]);

  /*
  Uint start, goal;
  if(fscanf(stdin, "%d %d\n", &start, &goal) != 2){
    exit(-1);    
  }
  */

  if(fscanf(fp, "%d %d\n", &number_of_nodes, &number_of_edges) != 2){
    exit(-1);
  }

  /*
  if(fscanf(stdin, "%d %d\n", &number_of_nodes, &number_of_edges) != 2){
    exit(-1);
  }
  */

  if(number_of_nodes > MAX_NODES || number_of_edges > (MAX_PAGES * PAGE_SIZE)){
    printf("Graph size exceeds the maximum memory capacity.");
    return -1;
  }

  node_index = 0;
  page_index = 0;
  frontiers_tail = NULL;

#ifndef __STATIC__  
  node_array = (Node*) malloc(sizeof(Node) * MAX_NODES);
  page_array = (Page*) malloc(sizeof(Page) * MAX_PAGES);
  //hashtable = (Node**) malloc(sizeof(Node*) * HASHTABLE_SIZE);
#endif

  /*
  Uint i;
  for(i=0; i<HASHTABLE_SIZE; i++){
    hashtable[i] = NULL;
  }
  */

  Uint from, to, cost;

  Uint i;
  for(i=0; i<MAX_NODES; i++){
    node_array[i].next_node_page_chain = NULL;
  }

  while(fscanf(fp, "%d %d %d\n", &from, &to, &cost) == 3){
    add_edge(from, to, cost);
    //add_edge(to, from, cost); // undirected graph
  }

  /*
  while(fscanf(stdin, "%d %d %d\n", &from, &to, &cost) == 3){
    add_edge(from, to, cost);
    //add_edge(to, from, cost); // undirected graph
  }
  */

  printf("start:%d goal:%d\r\n", start, goal);
  printf("num_nodes:%d num_edges:%d\r\n", number_of_nodes, number_of_edges);

  Uint sum_of_cost = compute(start, goal);

  walk_result(sum_of_cost, start, goal);

#ifndef __STATIC__  
  free(node_array);
  free(page_array);
  //free(hashtable);
#endif

  return 0;
}
